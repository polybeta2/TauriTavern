#!/bin/bash
set -e

DEVELOPER_DIR=$(xcode-select -p)
REAL="${DEVELOPER_DIR}/usr/bin/xcodebuild.real"

for arg in "$@"; do
  if [ "$arg" = "-version" ] || [ "$arg" = "-runFirstLaunch" ]; then
    exec "$REAL" "$@"
  fi
done

NEW_ARGS=()
for arg in "$@"; do
  if [ "$arg" != "-allowProvisioningUpdates" ]; then
    NEW_ARGS+=("$arg")
  fi
done

NEW_ARGS+=(
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=""
  CODE_SIGN_ENTITLEMENTS=""
  DEVELOPMENT_TEAM=""
)

echo "[xcodebuild-wrapper] Executing real xcodebuild with code signing disabled"
exec "$REAL" "${NEW_ARGS[@]}"
