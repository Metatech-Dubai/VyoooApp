#!/usr/bin/env bash
# Sync firestore/app_config_version_policy.json from pubspec.yaml.
# Optionally push to Firestore after the build is live in the stores.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS="$ROOT/functions"
NODE_SCRIPT="$FUNCTIONS/scripts/sync-version-policy-from-pubspec.js"

force_update=0
push_firestore=0
dry_run=0

usage() {
  cat <<'EOF'
Usage: ./scripts/sync_version_policy.sh [options]

Syncs firestore/app_config_version_policy.json from pubspec.yaml:
  - latestVersion  ← marketing version (e.g. 1.2.4)
  - minBuildNumber ← build number (e.g. 50)

Options:
  --force-update   Also set minVersion (blocks older app versions)
  --push           Push policy to Firestore (requires admin credentials)
  --dry-run        Show changes without writing
  -h, --help       Show this help

Examples:
  ./scripts/sync_version_policy.sh
  ./scripts/sync_version_policy.sh --force-update --push
EOF
}

for arg in "$@"; do
  case "$arg" in
    --force-update) force_update=1 ;;
    --push) push_firestore=1 ;;
    --dry-run) dry_run=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      usage
      exit 1
      ;;
  esac
done

sync_args=()
if [[ "$force_update" -eq 1 ]]; then
  sync_args+=(--force-update)
fi
if [[ "$dry_run" -eq 1 ]]; then
  sync_args+=(--dry-run)
fi

node "$NODE_SCRIPT" "${sync_args[@]}"

if [[ "$push_firestore" -eq 1 ]]; then
  if [[ "$dry_run" -eq 1 ]]; then
    echo "Dry-run — would push app_config/version_policy to Firestore."
    exit 0
  fi

  if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
    for candidate in \
      "$HOME/Downloads"/vyooov1-firebase-adminsdk-*.json; do
      if [[ -f "$candidate" ]]; then
        export GOOGLE_APPLICATION_CREDENTIALS="$candidate"
        break
      fi
    done
  fi

  if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" || ! -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
    echo "Set GOOGLE_APPLICATION_CREDENTIALS to a Firebase Admin SDK key, then re-run with --push."
    exit 1
  fi

  echo ""
  echo "Pushing to Firestore (vyooov1 / app_config/version_policy)..."
  (cd "$FUNCTIONS" && node scripts/seed-version-policy.js --commit)
fi
