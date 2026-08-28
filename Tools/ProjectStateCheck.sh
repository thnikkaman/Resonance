#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  printf '%s\n' "Usage: Tools/ProjectStateCheck.sh --source-only | --simulator <UDID>"
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

branch=$(git branch --show-current)
commit=$(git rev-parse HEAD)
remote=$(git remote get-url origin)
project_file="Resonance.xcodeproj/project.pbxproj"

if [[ "$branch" != "agent/alpha-3.7.4-source" ]]; then
  printf 'Unexpected branch: %s\n' "$branch" >&2
  exit 1
fi

versions=$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/p' "$project_file" | sort -u)
builds=$(sed -n 's/.*CURRENT_PROJECT_VERSION = \([^;]*\);.*/\1/p' "$project_file" | sort -u)
version_count=$(printf '%s\n' "$versions" | awk 'NF { count += 1 } END { print count + 0 }')
build_count=$(printf '%s\n' "$builds" | awk 'NF { count += 1 } END { print count + 0 }')

if [[ "$version_count" -ne 1 || "$build_count" -ne 1 ]]; then
  printf '%s\n' "Project settings do not have one unambiguous default version/build." >&2
  exit 1
fi

printf '%s\n' "Repository: $remote"
printf '%s\n' "Branch: $branch"
printf '%s\n' "Checkout commit: $commit"
printf '%s\n' "Project default: ${versions}/${builds}"

case "$1" in
  --source-only)
    exit 0
    ;;
  --simulator)
    if [[ $# -ne 2 ]]; then
      usage >&2
      exit 2
    fi
    simulator="$2"
    app_path=$(xcrun simctl get_app_container "$simulator" com.example.ResonancePrototype app)
    artifact_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Info.plist")
    artifact_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Info.plist")
    printf '%s\n' "Simulator: $simulator"
    printf '%s\n' "Installed artifact: $artifact_version/$artifact_build"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
