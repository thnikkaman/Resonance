#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMMON=(
  -project Resonance.xcodeproj
  -target Resonance
  -configuration Debug
  CODE_SIGNING_ALLOWED=NO
  SWIFT_VERSION=6
  SWIFT_STRICT_CONCURRENCY=complete
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
)

# Current-SDK simulator compile catches SwiftUI generic/initializer and
# concurrency diagnostics before a device install is attempted.
xcodebuild "${COMMON[@]}" \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  clean build

# A generic physical-device compile catches APIs that differ between the
# simulator and the current iPhoneOS SDK without requiring signing.
xcodebuild "${COMMON[@]}" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  clean build
