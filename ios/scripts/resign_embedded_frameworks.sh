#!/bin/bash
# Re-sign embedded frameworks after Flutter/CocoaPods embed (fixes
# objective_c.framework invalid signature 0xe8008014 on physical devices).
set -euo pipefail

APP="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
FRAMEWORKS_DIR="${APP}/Frameworks"

if [[ ! -d "${FRAMEWORKS_DIR}" ]]; then
  exit 0
fi

if [[ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" || "${EXPANDED_CODE_SIGN_IDENTITY}" == "-" ]]; then
  echo "warning: resign_embedded_frameworks: no signing identity, skipping"
  exit 0
fi

find "${FRAMEWORKS_DIR}" -depth -type d -name '*.framework' | while read -r fw; do
  /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
    --preserve-metadata=identifier,entitlements,flags \
    --timestamp=none "${fw}" || true
done
