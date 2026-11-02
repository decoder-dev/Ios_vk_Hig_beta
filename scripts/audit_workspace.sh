#!/usr/bin/env bash
set -euo pipefail
printf '\n=== WORKSPACE ===\n'
pwd
printf '\n=== GIT STATUS ===\n'
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git status --short
  git rev-parse --short HEAD
else
  echo 'No Git repository here'
fi
printf '\n=== XCODE WORKSPACES / PROJECTS ===\n'
find . -maxdepth 5 \( -name '*.xcworkspace' -o -name '*.xcodeproj' -o -name 'Package.swift' \) -print | head -100
printf '\n=== AVAILABLE TOOLCHAINS ===\n'
if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -version
else
  echo 'xcodebuild unavailable — compilation NOT RUN'
fi
if command -v swift >/dev/null 2>&1; then swift --version; fi
printf '\n=== NEXT STEPS ===\n'
echo 'Open real iOS project. Pick real scheme and simulator. Record every command and result in output/TEST_RESULTS.md.'
