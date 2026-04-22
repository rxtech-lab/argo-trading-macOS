#!/bin/bash
set -e

APP_PATH="output/output.xcarchive/Products/Applications/ArgoTradingSwift.app"
ENTITLEMENTS_PATH="ArgoTradingSwift/ArgoTradingSwift.entitlements"

if [ -z "${SIGNING_CERTIFICATE_NAME}" ]; then
  echo "Error: SIGNING_CERTIFICATE_NAME is not set"
  exit 1
fi

if [ ! -f "$ENTITLEMENTS_PATH" ]; then
  echo "Error: entitlements file not found at $ENTITLEMENTS_PATH"
  exit 1
fi

# Sign the main Sparkle framework binary first
codesign --force --options runtime --timestamp --sign "${SIGNING_CERTIFICATE_NAME}" "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle"

# Sign Sparkle components
codesign --force --options runtime --timestamp --sign "${SIGNING_CERTIFICATE_NAME}" "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign --force --options runtime --timestamp --sign "${SIGNING_CERTIFICATE_NAME}" "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign --force --options runtime --timestamp --sign "${SIGNING_CERTIFICATE_NAME}" "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
codesign --force --options runtime --timestamp --sign "${SIGNING_CERTIFICATE_NAME}" "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"

# Sign the Sparkle framework as a whole
codesign --force --options runtime --timestamp --sign "${SIGNING_CERTIFICATE_NAME}" "$APP_PATH/Contents/Frameworks/Sparkle.framework"

# Re-sign the main app binary explicitly (must pass entitlements — --force
# without --entitlements strips the entitlements Xcode embedded during archive)
codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS_PATH" --sign "${SIGNING_CERTIFICATE_NAME}" "$APP_PATH/Contents/MacOS/ArgoTradingSwift"

# Re-sign the main app to ensure everything is properly signed
codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS_PATH" --sign "${SIGNING_CERTIFICATE_NAME}" "$APP_PATH"

echo "Signing completed successfully"
