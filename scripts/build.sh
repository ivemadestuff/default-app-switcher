#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="${CONFIGURATION:-release}"
version="$(sed -n 's/.*static let version = "\(.*\)"/\1/p' "$project_root/app/Sources/Core/AppMetadata.swift")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Invalid application version.\n' >&2; exit 1; }
[[ ! -L "$project_root/dist" ]] || { printf 'Refusing to replace a symlink at dist.\n' >&2; exit 1; }
stage="$(mktemp -d "$project_root/.build-stage.XXXXXX")"
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Building Default App Switcher (%s)...\n' "$configuration"
swift build -c "$configuration" --package-path "$project_root/app" --product das
swift build -c "$configuration" --package-path "$project_root/app" --product das-helper
binary_dir="$(swift build -c "$configuration" --package-path "$project_root/app" --show-bin-path)"
app="$stage/das-helper.app"
mkdir -p "$app/Contents/MacOS"
cp "$binary_dir/das-helper" "$app/Contents/MacOS/das-helper"
cp "$binary_dir/das" "$stage/das"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>das-helper</string>
  <key>CFBundleIdentifier</key><string>dev.defaultappswitcher.helper</string>
  <key>CFBundleName</key><string>Default App Switcher Helper</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSHumanReadableCopyright</key><string>MIT</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - --timestamp=none "$app"
codesign --verify --strict "$app"
[[ "$("$stage/das" --version)" == "$version" ]] || { printf 'Built CLI failed version verification.\n' >&2; exit 1; }
rm -rf -- "$project_root/dist"
mkdir "$project_root/dist"
mv "$stage/das" "$stage/das-helper.app" "$project_root/dist/"
printf 'Built dist/das and dist/das-helper.app.\n'
