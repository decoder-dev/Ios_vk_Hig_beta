#!/usr/bin/env bash
set -euo pipefail
# Run only on macOS with Xcode and an actual project opened.
# The calling workspace needs an actual <YOUR_SCHEME> and <YOUR_PROJECT>.
SCHEME="${SCHEME:-}"
PROJECT="${PROJECT:-}"
DEVICE="${DEVICE:-iPhone 17 Pro}"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'NOT RUN: Xcode requires macOS'
  exit 2
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo 'NOT RUN: xcodebuild unavailable'
  exit 2
fi
if [[ -z "$SCHEME" || -z "$PROJECT" || ! -e "$PROJECT" ]]; then
  echo 'Set SCHEME and PROJECT environment variables to valid scheme and .xcodeproj/.xcworkspace path.'
  exit 2
fi
if [[ "$PROJECT" == *.xcworkspace ]]; then
  PROJECT_FLAG=(-workspace "$PROJECT")
else
  PROJECT_FLAG=(-project "$PROJECT")
fi
xcodebuild "${PROJECT_FLAG[@]}" -list
xcodebuild "${PROJECT_FLAG[@]}" -scheme "$SCHEME" -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=$DEVICE" build
xcodebuild "${PROJECT_FLAG[@]}" -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$DEVICE" test
