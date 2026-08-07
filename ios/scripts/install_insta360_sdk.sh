#!/usr/bin/env bash
#
# Copy the Insta360 iOS SDK (v1.9.2) xcframeworks into ios/Frameworks/ so the local
# `INSCameraSDK` pod can vendor them. Run this on the Mac BEFORE `pod install`.
#
# The framework binaries are intentionally NOT committed to git (too large), so this step must be
# run once per checkout / whenever the SDK is updated.
#
# Usage:
#   ios/scripts/install_insta360_sdk.sh [PATH_TO_SDK_Frameworks_DIR]
#
# If no path is given it tries INSTA360_IOS_SDK (env var) then a few common locations relative to
# the repo. PATH_TO_SDK_Frameworks_DIR must be the folder that directly contains
# INSCameraSDK.xcframework, INSCameraServiceSDK.xcframework and INSCoreMedia.xcframework.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="$IOS_DIR/Frameworks"

FRAMEWORKS=(INSCameraSDK.xcframework INSCameraServiceSDK.xcframework INSCoreMedia.xcframework)

candidates=()
if [[ $# -ge 1 ]]; then candidates+=("$1"); fi
if [[ -n "${INSTA360_IOS_SDK:-}" ]]; then candidates+=("$INSTA360_IOS_SDK"); fi
# Common layouts relative to the repo root (adjust to your machine as needed).
REPO_ROOT="$(cd "$IOS_DIR/.." && pwd)"
candidates+=(
  "$REPO_ROOT/../SDKs/iOS-SDK-1.9.2/iOS_v1.9.2/INSCameraSDKSample-bluetooth/Frameworks"
  "$REPO_ROOT/../SDKs/iOS-SDK-1.9.2/iOS_v1.9.2/Frameworks"
)

SRC=""
for c in "${candidates[@]}"; do
  if [[ -d "$c/INSCameraSDK.xcframework" ]]; then SRC="$c"; break; fi
done

if [[ -z "$SRC" ]]; then
  echo "ERROR: could not find the SDK Frameworks folder." >&2
  echo "Pass it explicitly, e.g.:" >&2
  echo "  ios/scripts/install_insta360_sdk.sh /path/to/iOS_v1.9.2/INSCameraSDKSample-bluetooth/Frameworks" >&2
  exit 1
fi

echo "Source: $SRC"
echo "Dest:   $DEST"
mkdir -p "$DEST"

for fw in "${FRAMEWORKS[@]}"; do
  if [[ ! -d "$SRC/$fw" ]]; then
    echo "ERROR: missing $fw in $SRC" >&2
    exit 1
  fi
  echo "Copying $fw ..."
  rm -rf "${DEST:?}/$fw"
  cp -R "$SRC/$fw" "$DEST/$fw"
done

echo "Done. Now run:  cd ios && pod install"
