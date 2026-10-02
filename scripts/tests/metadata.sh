#!/bin/bash
set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/das-metadata-tests.XXXXXX")
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/app/Sources/Core"
metadata="$fixture/app/Sources/Core/AppMetadata.swift"
printf '# App\n\nSwitch default apps.\n' > "$fixture/README.md"
checks=0

write_metadata() {
  printf 'package enum AppMetadata {\n    package static let version = "%s"\n    package static let description = "Switch default apps."\n    package static let extra = "Preserved value"\n}\n' "$1" > "$metadata"
}

rejects() {
  cp "$metadata" "$fixture/before.swift"
  if "$@" > /dev/null 2>&1; then
    printf 'Accepted invalid metadata or release version.\n' >&2
    exit 1
  fi
  cmp "$metadata" "$fixture/before.swift"
  checks=$((checks + 1))
}

for version in 0.1.0 100.23.45; do
  write_metadata "$version"
  bash "$script_root/check.sh" "$fixture"
  checks=$((checks + 1))
done
for version in invalid v1.0.0 1.0.0-beta.1 01.0.0 ''; do
  write_metadata "$version"
  rejects bash "$script_root/check.sh" "$fixture"
  rejects bash "$script_root/version.sh" 1.0.0 "$fixture"
done
printf 'package enum AppMetadata {}\n' > "$metadata"
rejects bash "$script_root/version.sh" 1.0.0 "$fixture"

write_metadata 0.1.0
sed 's/version = "0.1.0"/version = "100.23.45"/' "$metadata" > "$fixture/expected.swift"
bash "$script_root/version.sh" 100.23.45 "$fixture"
cmp "$metadata" "$fixture/expected.swift"
bash "$script_root/check.sh" "$fixture"
checks=$((checks + 1))
for version in invalid v1.0.0 1.0.0-beta.1 01.0.0 '' $'1.0.0"\ninvalid'; do
  rejects bash "$script_root/version.sh" "$version" "$fixture"
done
printf '# App\n\nDifferent description.\n' > "$fixture/README.md"
rejects bash "$script_root/check.sh" "$fixture"
rejects bash "$script_root/version.sh" 1.0.0 "$fixture"
printf 'Passed %s metadata checks.\n' "$checks"
