#!/bin/sh
set -eu

manifest="$SRCROOT/Resonance/PrivacyInfo.xcprivacy"
case " ${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-} " in
  *" RESONANCE_TELEMETRY "*)
    manifest="$SRCROOT/Resonance/PrivacyInfo-Internal.xcprivacy"
    ;;
esac

destination="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/PrivacyInfo.xcprivacy"
mkdir -p "$(dirname "$destination")"
cp "$manifest" "$destination"
