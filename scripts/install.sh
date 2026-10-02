#!/bin/bash
set -euo pipefail

work_dir=""
install_stage=""
lock_dir=""

fail() {
  printf 'default-app-switcher: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -z "$work_dir" ]] || rm -rf -- "$work_dir"
  [[ -z "$install_stage" ]] || rm -rf -- "$install_stage"
  [[ -z "$lock_dir" ]] || rmdir -- "$lock_dir"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

download() {
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 \
    --fail --silent --show-error --location --retry 2 \
    --connect-timeout 15 --max-time 300 --output "$2" "$1"
}

configure_path() {
  local shell_name="${SHELL:-}" config="" candidate="" path_line='export PATH="$HOME/.local/bin:$PATH"'
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) return ;;
  esac
  case "${shell_name##*/}" in
    zsh) config="${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash)
      config="$HOME/.bash_profile"
      for candidate in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
        if [[ -f "$candidate" ]]; then
          config="$candidate"
          break
        fi
      done
      ;;
  esac
  if [[ -n "$config" ]]; then
    if [[ -f "$config" ]] && grep -Fqx "$path_line" "$config"; then
      printf 'Open a new terminal to use das.\n'
      return
    fi
    if (printf '\n%s\n' "$path_line" >> "$config"); then
      printf 'Added ~/.local/bin to PATH in %s. Open a new terminal to use das.\n' "$config"
      return
    fi
  fi
  printf 'Add ~/.local/bin to your shell configuration for PATH. You can also run %s/.local/bin/das directly.\n' "$HOME"
}

uninstall() {
  local root="$HOME/.local/share/default-app-switcher" bin="$HOME/.local/bin/das"
  if [[ -e "$root" || -L "$root" ]]; then
    [[ -d "$root" && ! -L "$root" && -f "$root/.installer-managed" && ! -L "$root/.installer-managed" ]] \
      || fail "Refusing to remove an unmanaged directory: $root"
    if ! mkdir "$root/.install-lock" 2>/dev/null; then
      fail "Another installation may be running. If it was interrupted, remove $root/.install-lock and retry."
    fi
    lock_dir="$root/.install-lock"
  fi

  if [[ -L "$bin" && "$(readlink "$bin")" == "$root/current/das" ]]; then
    rm -- "$bin"
  elif [[ -e "$bin" || -L "$bin" ]]; then
    printf 'Preserved unrelated command: %s\n' "$bin"
  fi
  if [[ -n "$lock_dir" ]]; then
    rm -rf -- "$root"
    lock_dir=""
  fi
  printf 'Default App Switcher installer files removed. Shared ~/.local/bin and shell configuration were preserved.\n'
}

main() {
  [[ $# -le 1 ]] || fail 'Expected at most one option. Use --help for usage.'
  case "${1:-}" in
    --help|-h)
      printf 'Usage: install.sh [--uninstall | --help]\n\nWithout options, install or update to the latest release.\n--uninstall  Remove installed files\n'
      return
      ;;
    ''|--uninstall) ;;
    *) fail "Unknown option: $1. Use --help for usage." ;;
  esac
  [[ "$(uname -s)" == Darwin ]] || fail 'This installer supports macOS only.'
  [[ "$HOME" == /* && "$HOME" != / ]] || fail 'HOME must be an absolute user directory.'
  [[ "$EUID" -ne 0 ]] || fail 'Run this installer as your user, without sudo.'
  if [[ "${1:-}" == --uninstall ]]; then
    uninstall
    return
  fi
  local command
  for command in swift curl tar plutil codesign; do
    command -v "$command" >/dev/null 2>&1 || fail "Required command not found: $command. Install it first."
  done
  local swift_version
  swift_version=$(swift --version | sed -n 's/.*Swift version \([0-9]*\)\..*/\1/p' | head -n 1)
  [[ "$swift_version" =~ ^[0-9]+$ && "$swift_version" -ge 6 ]] || fail 'Building requires Swift 6 or later. Update the Xcode Command Line Tools.'

  local root="$HOME/.local/share/default-app-switcher" bin="$HOME/.local/bin/das"
  if [[ -e "$root" || -L "$root" ]]; then
    [[ -d "$root" && ! -L "$root" && -f "$root/.installer-managed" && ! -L "$root/.installer-managed" ]] || fail "Refusing to replace an unmanaged directory: $root"
  fi
  if [[ -e "$bin" || -L "$bin" ]]; then
    [[ -L "$bin" && "$(readlink "$bin")" == "$root/current/das" ]] || fail "Another das command already exists at $bin. Move it before installing."
  fi
  if [[ -e "$root/current" || -L "$root/current" ]]; then
    [[ -L "$root/current" ]] || fail "Refusing to replace $root/current: expected an installer symlink."
  fi

  work_dir=$(mktemp -d "${TMPDIR:-/tmp}/default-app-switcher.XXXXXX")
  download 'https://api.github.com/repos/ivemadestuff/default-app-switcher/releases/latest' "$work_dir/release.json" \
    || fail 'Could not fetch the latest release. A published GitHub Release and an internet connection are required.'
  local tag version_dir
  tag=$(plutil -extract tag_name raw -o - "$work_dir/release.json") || fail 'GitHub did not return a release tag.'
  [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'GitHub did not return a valid stable release.'
  [[ "$(plutil -extract draft raw -o - "$work_dir/release.json")" == false && "$(plutil -extract prerelease raw -o - "$work_dir/release.json")" == false ]] \
    || fail 'GitHub did not return a stable published release.'
  version_dir="$root/$tag"

  mkdir -p "$root" "$HOME/.local/bin"
  if ! mkdir "$root/.install-lock" 2>/dev/null; then
    fail "Another installation may be running. If it was interrupted, remove $root/.install-lock and retry."
  fi
  lock_dir="$root/.install-lock"
  touch "$root/.installer-managed"
  install_stage=$(mktemp -d "$root/.staging.XXXXXX")

  [[ ! -L "$version_dir" ]] || fail "Refusing to use a symlink as a release directory: $version_dir"
  if [[ -e "$version_dir" && ! -d "$version_dir" ]]; then
    fail "Refusing to replace an unrelated file: $version_dir"
  fi
  if [[ ! -d "$version_dir" ]]; then
    printf 'Downloading and building Default App Switcher %s...\n' "$tag"
    download "https://github.com/ivemadestuff/default-app-switcher/archive/refs/tags/$tag.tar.gz" "$work_dir/source.tar.gz"
    mkdir "$work_dir/source"
    tar -xzf "$work_dir/source.tar.gz" -C "$work_dir/source" --strip-components=1
    local version
    version=$(sed -n 's/.*static let version = "\(.*\)"/\1/p' "$work_dir/source/app/Sources/Core/AppMetadata.swift")
    [[ "$version" == "${tag#v}" ]] || fail 'Release archive does not match its version tag.'
    (cd "$work_dir/source" && bash scripts/build.sh </dev/null)
    mkdir "$install_stage/package"
    cp -R "$work_dir/source/dist/." "$install_stage/package/"
    cp "$work_dir/source/LICENSE" "$install_stage/package/"
    [[ "$("$install_stage/package/das" --version)" == "${tag#v}" ]] || fail 'Built CLI failed version verification.'
    codesign --verify --strict "$install_stage/package/das-helper.app" || fail 'Built helper failed signature verification.'
    mv "$install_stage/package" "$version_dir"
  fi
  [[ "$("$version_dir/das" --version)" == "${tag#v}" ]] || fail "Installed release is damaged: $version_dir. Uninstall it and run the installer again."
  codesign --verify --strict "$version_dir/das-helper.app" || fail 'Installed helper failed signature verification.'
  ln -s "$version_dir" "$install_stage/current"
  /bin/mv -h -f "$install_stage/current" "$root/current"
  if [[ ! -L "$bin" ]]; then
    ln -s "$root/current/das" "$bin"
  fi

  printf 'Installed Default App Switcher %s.\n' "$tag"
  configure_path
  printf 'Run: das --help\n'
}

main "$@"
