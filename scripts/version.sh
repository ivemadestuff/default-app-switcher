#!/bin/bash
set -euo pipefail

version="${1:-}"
[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] \
  || { printf 'Invalid release version.\n' >&2; exit 1; }
script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="${2:-$(cd "$script_root/.." && pwd)}"
bash "$script_root/check.sh" "$project_root"
metadata="$project_root/app/Sources/Core/AppMetadata.swift"
stage=$(mktemp "$metadata.XXXXXX")
trap 'rm -f -- "$stage"' EXIT
sed "s/^    package static let version = \"[^\"]*\"$/    package static let version = \"$version\"/" "$metadata" > "$stage"
chmod 644 "$stage"
mv "$stage" "$metadata"
