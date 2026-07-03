#!/usr/bin/env bash
# Bump only the build number (+N) in pubspec.yaml per docs/VERSIONING.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$ROOT/pubspec.yaml"

if [[ ! -f "$PUBSPEC" ]]; then
  echo "pubspec.yaml not found at $PUBSPEC"
  exit 1
fi

line="$(grep -E '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' "$PUBSPEC" | head -1)"
if [[ -z "$line" ]]; then
  echo "Could not parse version: line in pubspec.yaml"
  exit 1
fi

marketing="$(echo "$line" | sed -E 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+.*/\1/')"
build="$(echo "$line" | sed -E 's/^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+).*/\1/')"
next=$((build + 1))

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "Would change: ${marketing}+${build} → ${marketing}+${next}"
  exit 0
fi

if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s/^version: ${marketing}+${build}/version: ${marketing}+${next}/" "$PUBSPEC"
else
  sed -i "s/^version: ${marketing}+${build}/version: ${marketing}+${next}/" "$PUBSPEC"
fi

echo "Updated pubspec.yaml: ${marketing}+${build} → ${marketing}+${next}"

SYNC_SCRIPT="$ROOT/scripts/sync_version_policy.sh"
if [[ -x "$SYNC_SCRIPT" ]]; then
  "$SYNC_SCRIPT"
else
  bash "$SYNC_SCRIPT"
fi

echo ""
echo "Next steps:"
echo "  1. fvm flutter pub get"
echo "  2. Add a row to docs/VERSIONING.md (Release history)"
echo "  3. Upload to Play / App Store Connect"
echo "  4. After live: ./scripts/sync_version_policy.sh --force-update --push"
