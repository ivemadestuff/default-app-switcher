#!/bin/bash
set -euo pipefail

installer="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install.sh"
workspace=$(mktemp -d "${TMPDIR:-/tmp}/das-installer-tests.XXXXXX")
trap 'rm -rf -- "$workspace"' EXIT
checks=0

expect() {
  checks=$((checks + 1))
  local message="$1"
  shift
  if ! "$@"; then
    printf 'Failed: %s\n' "$message" >&2
    [[ ! -f "$workspace/output" ]] || cat "$workspace/output" >&2
    exit 1
  fi
}

release() {
  local version="${1:-1.0.0}" source="$fixture/source"
  printf '{"tag_name":"%s","draft":%s,"prerelease":%s}\n' \
    "${2:-v$version}" "${3:-false}" "${4:-false}" > "$fixture/release.json"
  mkdir -p "$source/app/Sources/Core" "$source/scripts"
  printf '    package static let version = "%s"\n' "$version" > "$source/app/Sources/Core/AppMetadata.swift"
  printf 'Test fixture\n' > "$source/LICENSE"
  cat > "$source/scripts/build.sh" <<'BUILD'
#!/bin/bash
set -eu
[[ "${FAIL_BUILD:-0}" != 1 ]] || exit 1
version=$(sed -n 's/.*version = "\(.*\)"/\1/p' app/Sources/Core/AppMetadata.swift)
mkdir -p dist/das-helper.app/Contents/MacOS
printf '#!/bin/bash\nprintf "%s\\n"\n' "$version" > dist/das
chmod +x dist/das
cp dist/das dist/das-helper.app/Contents/MacOS/das-helper
BUILD
  tar -czf "$fixture/source.tar.gz" -C "$fixture" source
}

setup() {
  fixture=$(mktemp -d "$workspace/case.XXXXXX")
  test_home="$fixture/home with spaces"
  root="$test_home/.local/share/default-app-switcher"
  command_path="$test_home/.local/bin/das"
  mkdir -p "$test_home" "$fixture/bin"
  printf '#!/bin/bash\nprintf "Apple Swift version 6.0.0\\n"\n' > "$fixture/bin/swift"
  printf '#!/bin/bash\n[[ "${FAIL_SIGNATURE:-0}" != 1 ]]\n' > "$fixture/bin/codesign"
  cat > "$fixture/bin/curl" <<'CURL'
#!/bin/bash
set -eu
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    *) url="$1"; shift ;;
  esac
done
[[ "${FAIL_DOWNLOAD:-0}" != 1 ]] || exit 22
case "$url" in
  */releases/latest) cp "$FIXTURE_DIR/release.json" "$output" ;;
  */archive/refs/tags/*.tar.gz) cp "$FIXTURE_DIR/source.tar.gz" "$output" ;;
  *) exit 2 ;;
esac
CURL
  chmod +x "$fixture/bin/"*
  release
}

run() {
  env -i HOME="$test_home" PATH="$fixture/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    SHELL="${TEST_SHELL:-/bin/zsh}" FIXTURE_DIR="$fixture" TMPDIR="$fixture" \
    FAIL_BUILD="${FAIL_BUILD:-0}" FAIL_DOWNLOAD="${FAIL_DOWNLOAD:-0}" \
    FAIL_SIGNATURE="${FAIL_SIGNATURE:-0}" \
    /bin/bash "$installer" "$@" > "$workspace/output" 2>&1
}

rejects() {
  if run "$@"; then return 1; fi
}

setup
expect 'installation succeeds' run
expect 'command links to the managed release' test "$(readlink "$command_path")" = "$root/current/das"
expect 'the initial release is selected' test "$(readlink "$root/current")" = "$root/v1.0.0"
configuration=$(cat "$test_home/.zshrc")
expect 'zsh receives the command path' grep -Fq '.local/bin' "$test_home/.zshrc"
expect 'reinstallation succeeds' run
expect 'zsh configuration is not duplicated' test "$(cat "$test_home/.zshrc")" = "$configuration"
release 1.1.0
expect 'update succeeds' run
expect 'the new release is selected' test "$(readlink "$root/current")" = "$root/v1.1.0"
expect 'uninstall succeeds' run --uninstall
expect 'managed files are removed' test ! -e "$root"
expect 'the command link is removed' test ! -L "$command_path"
expect 'shell configuration is preserved' test "$(cat "$test_home/.zshrc")" = "$configuration"
expect 'the shared bin directory is preserved' test -d "$test_home/.local/bin"

for failure in FAIL_BUILD FAIL_DOWNLOAD FAIL_SIGNATURE; do
  setup
  expect 'the original release installs' run
  release 1.1.0
  printf -v "$failure" '%s' 1
  expect 'a failed update is rejected' rejects
  unset "$failure"
  expect 'a failed update preserves the original release' test "$(readlink "$root/current")" = "$root/v1.0.0"
  expect 'a failed update clears its lock' test ! -e "$root/.install-lock"
  expect 'a failed update can be retried' run
  expect 'the retry selects the new release' test "$(readlink "$root/current")" = "$root/v1.1.0"
done

setup
mkdir -p "$(dirname "$command_path")"
printf 'unrelated' > "$command_path"
expect 'unrelated commands block installation' rejects
expect 'uninstall preserves unrelated commands' run --uninstall
expect 'the unrelated command is intact' test "$(cat "$command_path")" = unrelated
mkdir -p "$root"
printf 'unrelated' > "$root/keep"
expect 'unmanaged directories block uninstall' rejects --uninstall
expect 'unmanaged files are intact' test "$(cat "$root/keep")" = unrelated

setup
mkdir -p "$(dirname "$root")"
ln -s "$fixture" "$root"
expect 'symlinked roots block installation' rejects
expect 'symlinked roots block uninstall' rejects --uninstall
expect 'the unrelated symlink is intact' test "$(readlink "$root")" = "$fixture"

setup
expect 'installation before lock test succeeds' run
mkdir "$root/.install-lock"
expect 'the lock blocks installation' rejects
expect 'the lock blocks uninstall' rejects --uninstall
expect 'the lock preserves the command' test -e "$command_path"
expect 'another installer retains its lock' test -d "$root/.install-lock"

for invalid in draft prerelease tag; do
  setup
  case "$invalid" in
    draft) release 1.0.0 v1.0.0 true false ;;
    prerelease) release 1.0.0 v1.0.0 false true ;;
    tag) release 1.0.0 ../../unsafe ;;
  esac
  expect 'invalid release metadata blocks installation' rejects
  expect 'invalid releases create no command' test ! -e "$command_path"
done

setup
printf '# Existing configuration\n' > "$test_home/.profile"
TEST_SHELL=/bin/bash
expect 'bash installation succeeds' run
configuration=$(cat "$test_home/.profile")
expect 'bash receives the command path' grep -Fq '.local/bin' "$test_home/.profile"
expect 'bash reinstallation succeeds' run
expect 'bash configuration is not duplicated' test "$(cat "$test_home/.profile")" = "$configuration"
setup
TEST_SHELL=/bin/fish
expect 'other shells can install' run
expect 'other shells receive manual setup instructions' grep -Fq 'Add ~/.local/bin' "$workspace/output"
expect 'other shells do not receive zsh configuration' test ! -e "$test_home/.zshrc"
printf 'Passed %s installer checks.\n' "$checks"
