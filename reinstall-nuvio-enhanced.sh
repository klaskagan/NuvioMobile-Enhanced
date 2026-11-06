#!/bin/bash
set -euo pipefail

repo="${NUVIO_REPO:-/Users/klaskagan/code/Nuvio/NuvioMobile-Enhanced}"
device="${NUVIO_DEVICE:-92A68FDE-123B-5A89-9955-9C95FBBFEB05}"
bundle="com.klaskagan.nuvioenhanced"
cd "$repo"

project="iosApp/iosApp.xcodeproj/project.pbxproj"
source="iosApp/iosApp/ContentView.swift"
patch="build/device-install/ios-build.patch"
app="$repo/build/device-products/Debug-iphoneos/Nuvio Enhanced.app"
log="$repo/build/device-install/reinstall.log"
check_only=0
case "${1:-}" in
  --check) check_only=1 ;;
  "") ;;
  *) echo "Usage: bash $0 [--check]"; exit 2 ;;
esac

for command in git xcodebuild xcrun codesign; do
  command -v "$command" >/dev/null || { echo "Missing command: $command"; exit 1; }
done
JAVA_HOME="$(/usr/libexec/java_home -v 21)"
export JAVA_HOME
export NUVIO_IOS_DISTRIBUTION=full
[[ -f "$patch" ]] || { echo "Missing saved build patch: $patch"; exit 1; }
[[ -f local.properties ]] || { echo "Missing local.properties; restore your integration settings first."; exit 1; }
git diff --quiet HEAD -- "$project" "$source" || {
  echo "The project or ContentView.swift has local changes. Nothing was overwritten."
  exit 1
}
git apply --check --include="$project" --include="$source" "$patch"
if [[ "$check_only" == 1 ]]; then
  echo "Preflight passed. Patch applies; Java 21 and build tools are available."
  echo "No build, signing, device access, or installation was performed."
  exit 0
fi

lock="$repo/build/device-install/reinstall.lock"
mkdir "$lock" 2>/dev/null || {
  echo "Another reinstall may be running: $lock"
  echo "If an earlier run was forcibly terminated, confirm it has stopped before removing this empty lock directory."
  exit 1
}
backup=""
applied=0
cleanup() {
  status=$?
  trap - EXIT
  restored=0
  if [[ "$applied" == 1 ]]; then
    if cmp -s "$project" "$backup/project.patched" && cmp -s "$source" "$backup/source.patched"; then
      cp "$backup/project.original" "$project"
      cp "$backup/source.original" "$source"
      restored=1
      echo "Temporary source adjustments restored."
    else
      echo "Files changed during the build; automatic restoration skipped."
      echo "Original copies are preserved in: $backup"
      [[ "$status" != 0 ]] || status=1
    fi
  fi
  if [[ "$status" == 0 && "$restored" == 1 && -n "$backup" ]]; then
    rm -rf -- "$backup"
    echo "Installation succeeded; temporary source backup deleted."
  fi
  rmdir "$lock" 2>/dev/null || true
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

backup="$(mktemp -d /private/tmp/nuvio-reinstall.XXXXXX)"
cp "$project" "$backup/project.original"
cp "$source" "$backup/source.original"
git apply --include="$project" --include="$source" "$patch"
cp "$project" "$backup/project.patched"
cp "$source" "$backup/source.patched"
applied=1

echo "Keep the iPhone connected and unlocked."
echo "Building; follow progress with: tail -f '$log'"
if ! xcodebuild \
  -project iosApp/iosApp.xcodeproj -target iosApp \
  -configuration Debug -sdk iphoneos \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=26NPG3Y53E \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) NUVIO_LEGACY_SDK' \
  SYMROOT="$repo/build/device-products" \
  OBJROOT="$repo/build/device-intermediates" \
  build >"$log" 2>&1; then
  tail -60 "$log"
  echo "Build failed. Full log: $log"
  exit 1
fi
codesign --verify --deep --strict "$app"
xcrun devicectl device install app --device "$device" "$app" --timeout 120
xcrun devicectl device process launch --device "$device" --terminate-existing "$bundle" --timeout 30
echo "Nuvio Enhanced installed and launch request succeeded."
echo "If iOS still refuses to open it, check developer trust and signing rather than deleting the app."
