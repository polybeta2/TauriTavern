#!/bin/bash
set -e

DEVELOPER_DIR=$(xcode-select -p)
REAL="${DEVELOPER_DIR}/usr/bin/xcodebuild.real"

# If it's a query or utility command, pass through untouched
for arg in "$@"; do
  case "$arg" in
    -find|-version|-showsdks|-runFirstLaunch|-showBuildSettings|-help)
      exec "$REAL" "$@"
      ;;
  esac
done

# Only intercept actual build/archive actions
IS_BUILD=0
for arg in "$@"; do
  if [ "$arg" = "build" ] || [ "$arg" = "archive" ] || [ "$arg" = "-scheme" ]; then
    IS_BUILD=1
    break
  fi
done

if [ "$IS_BUILD" -eq 0 ]; then
  exec "$REAL" "$@"
fi

# Filter out -allowProvisioningUpdates
NEW_ARGS=()
for arg in "$@"; do
  if [ "$arg" != "-allowProvisioningUpdates" ]; then
    NEW_ARGS+=("$arg")
  fi
done

# Append unsigned overrides for the build action
NEW_ARGS+=(
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=""
  CODE_SIGN_ENTITLEMENTS=""
  DEVELOPMENT_TEAM=""
)

exec "$REAL" "${NEW_ARGS[@]}"
