#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Для проверки на устройстве нужен Mac с Xcode.' >&2; exit 1; }
: "${VK_APPLE_TEAM_ID:?Укажите VK_APPLE_TEAM_ID вашей команды Apple Developer}"
[[ "$VK_APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo 'Некорректный Team ID' >&2; exit 1; }
xcodegen generate
xcodebuild -scheme VKHIG -configuration Debug -destination 'generic/platform=iOS' -archivePath build/Device.xcarchive DEVELOPMENT_TEAM="$VK_APPLE_TEAM_ID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates archive
if [[ -n "${VK_DEVICE_UDID:-}" ]]; then
  xcodebuild -scheme VKHIG -configuration Debug -destination "platform=iOS,id=$VK_DEVICE_UDID" DEVELOPMENT_TEAM="$VK_APPLE_TEAM_ID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates -resultBundlePath build/DeviceTests.xcresult test
fi
