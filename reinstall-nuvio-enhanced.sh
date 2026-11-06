#!/bin/bash
set -euo pipefail

repo="${NUVIO_REPO:-/Users/klaskagan/code/Nuvio/NuvioMobile-Enhanced}"
device="${NUVIO_DEVICE:-92A68FDE-123B-5A89-9955-9C95FBBFEB05}"
bundle="com.klaskagan.nuvioenhanced"
cd "$repo"

app="$repo/build/device-products/Debug-iphoneos/Nuvio Enhanced.app"
log="$repo/build/device-install/reinstall.log"
check_only=0
case "${1:-}" in
  --check) check_only=1 ;;
  "") ;;
  *) echo "Usage: bash $0 [--check]"; exit 2 ;;
esac

for command in git python3 xcodebuild xcrun codesign; do
  command -v "$command" >/dev/null || { echo "Missing command: $command"; exit 1; }
done
JAVA_HOME="$(/usr/libexec/java_home -v 21)"
export JAVA_HOME
export NUVIO_IOS_DISTRIBUTION=full
[[ -f local.properties ]] || { echo "Missing local.properties; restore your integration settings first."; exit 1; }
[[ "$(git branch --show-current)" == develop ]] || { echo "Switch to develop before installing."; exit 1; }
git diff --quiet HEAD -- iosApp composeApp MPVKit || {
  echo "Build sources have local changes or MPVKit is not at the committed revision."
  exit 1
}
if [[ "$check_only" == 1 ]]; then
  echo "Preflight passed. No signing, build, or installation was performed."
  exit 0
fi

lock="$repo/build/device-install/reinstall.lock"
mkdir "$lock" 2>/dev/null || {
  echo "Another reinstall may be running: $lock"
  echo "If an earlier run was forcibly terminated, confirm it has stopped before removing this empty lock directory."
  exit 1
}
trap 'rmdir "$lock"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

python3 - "$bundle" <<'PYTHON'
import pathlib
import plistlib
import shutil
import sys
import tempfile

bundle = sys.argv[1]
identifiers = {
    f"26NPG3Y53E.{bundle}",
    f"26NPG3Y53E.{bundle}.DownloadsWidgetExtension",
}
cache = pathlib.Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles"
backup = None
for profile in cache.glob("*.mobileprovision"):
    data = profile.read_bytes()
    start = data.find(b"<?xml")
    end = data.find(b"</plist>", start)
    if start < 0 or end < 0:
        continue
    payload = plistlib.loads(data[start:end + len(b"</plist>")])
    if payload.get("Entitlements", {}).get("application-identifier") in identifiers:
        if backup is None:
            backup = pathlib.Path(tempfile.mkdtemp(prefix="nuvio-profiles-"))
            print(f"Backing up Nuvio profiles to {backup}", flush=True)
        shutil.move(profile, backup / profile.name)
PYTHON

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
python3 - "$app" <<'PYTHON'
from datetime import datetime, timedelta, timezone
from pathlib import Path
import plistlib
import sys
from zoneinfo import ZoneInfo

app = Path(sys.argv[1])
profiles = [app / "embedded.mobileprovision"]
profiles.extend(app.glob("PlugIns/*.appex/embedded.mobileprovision"))
now = datetime.now(timezone.utc)
for profile in profiles:
    data = profile.read_bytes()
    start = data.index(b"<?xml")
    end = data.index(b"</plist>", start)
    payload = plistlib.loads(data[start:end + len(b"</plist>")])
    expiry = payload["ExpirationDate"].replace(tzinfo=timezone.utc)
    print(f"{profile.parent.name} profile expires {expiry.astimezone(ZoneInfo('Europe/Vilnius')):%Y-%m-%d %H:%M %Z}", flush=True)
    if expiry - now < timedelta(days=6):
        sys.exit("Signing profile has less than six days left. Installation skipped.")
PYTHON
xcrun devicectl device install app --device "$device" "$app" --timeout 120
xcrun devicectl device process launch --device "$device" --terminate-existing "$bundle" --timeout 30
echo "Nuvio Enhanced installed and launch request succeeded."
echo "If iOS still refuses to open it, check developer trust and signing rather than deleting the app."
