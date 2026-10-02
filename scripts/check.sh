#!/bin/bash
set -euo pipefail

project_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
metadata="$project_root/app/Sources/Core/AppMetadata.swift"
version=$(sed -n 's/^    package static let version = "\([^"]*\)"$/\1/p' "$metadata")
description=$(sed -n 's/^    package static let description = "\([^"]*\)"$/\1/p' "$metadata")
[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] \
  || { printf 'Invalid application version.\n' >&2; exit 1; }
[[ -n "$description" && "$description" == "$(sed -n '3p' "$project_root/README.md")" ]] \
  || { printf 'README description does not match AppMetadata.swift.\n' >&2; exit 1; }
