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

# Intercept -exportArchive to package unsigned TrollStore IPA directly
IS_EXPORT=0
for arg in "$@"; do
  if [ "$arg" = "-exportArchive" ]; then
    IS_EXPORT=1
    break
  fi
done

if [ "$IS_EXPORT" -eq 1 ]; then
  ARCHIVE_PATH=""
  EXPORT_PATH=""
  PREV=""
  for arg in "$@"; do
    if [ "$PREV" = "-archivePath" ]; then
      ARCHIVE_PATH="$arg"
    elif [ "$PREV" = "-exportPath" ]; then
      EXPORT_PATH="$arg"
    fi
    PREV="$arg"
  done

  echo "[xcodebuild-wrapper] Intercepted -exportArchive" >&2
  echo "[xcodebuild-wrapper] ARCHIVE_PATH: $ARCHIVE_PATH" >&2
  echo "[xcodebuild-wrapper] EXPORT_PATH:  $EXPORT_PATH" >&2

  mkdir -p "$EXPORT_PATH/Payload"
  APP_DIR=$(find "$ARCHIVE_PATH/Products/Applications" -name "*.app" -type d 2>/dev/null | head -n 1)
  if [ -z "$APP_DIR" ]; then
    APP_DIR=$(find "$ARCHIVE_PATH" -name "*.app" -type d 2>/dev/null | head -n 1)
  fi

  if [ -z "$APP_DIR" ] || [ ! -d "$APP_DIR" ]; then
    echo "[xcodebuild-wrapper] ERROR: No .app found in $ARCHIVE_PATH" >&2
    exit 1
  fi

  APP_BASENAME=$(basename "$APP_DIR")
  echo "[xcodebuild-wrapper] Found app bundle: $APP_BASENAME" >&2
  cp -R "$APP_DIR" "$EXPORT_PATH/Payload/"

  # Ad-hoc sign the copied app bundle for TrollStore
  codesign --force --deep --sign - "$EXPORT_PATH/Payload/$APP_BASENAME" 2>/dev/null || true

  APP_NAME="${APP_BASENAME%.app}"
  ORIG_DIR=$(pwd)
  cd "$EXPORT_PATH"
  zip -r -9 "${APP_NAME}.ipa" Payload
  # Also create alias names so any expected filename matches
  cp "${APP_NAME}.ipa" "TauriTavern.ipa" 2>/dev/null || true
  cp "${APP_NAME}.ipa" "tauritavern.ipa" 2>/dev/null || true
  rm -rf Payload
  cd "$ORIG_DIR"

  echo "[xcodebuild-wrapper] Successfully created $EXPORT_PATH/${APP_NAME}.ipa" >&2
  exit 0
fi

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

# Append unsigned overrides for the build/archive action
NEW_ARGS+=(
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=""
  CODE_SIGN_ENTITLEMENTS=""
  DEVELOPMENT_TEAM=""
)

exec "$REAL" "${NEW_ARGS[@]}"
