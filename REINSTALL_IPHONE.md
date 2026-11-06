# Reinstall Nuvio Enhanced on your iPhone

This installs over `com.klaskagan.nuvioenhanced`, preserving its app data. Do not delete Enhanced first. Regular Nuvio uses a different identifier and remains installed.

## Before starting

1. Connect the iPhone by USB and keep it unlocked and online.
2. On the phone, open **Settings → General → VPN & Device Management**. If your developer account offers **Trust** or **Verify App**, complete that and try Enhanced again.
3. In **Xcode → Settings → Apple Accounts**, confirm your account shows **Personal Team**. Complete sign-in yourself if requested.
4. Close the Nuvio project in Xcode. Do not edit its project file or `ContentView.swift` during this procedure.

## One-command installation

```bash
bash /Users/klaskagan/code/Nuvio/NuvioMobile-Enhanced/reinstall-nuvio-enhanced.sh
```

To validate the local prerequisites without building or touching the phone:

```bash
bash /Users/klaskagan/code/Nuvio/NuvioMobile-Enhanced/reinstall-nuvio-enhanced.sh --check
```

The script applies the existing local signing/SDK patch, runs one Xcode build, checks the signature, installs, launches, and restores its two temporary source changes. It refuses conflicting edits or concurrent script runs. It never uninstalls apps or explicitly revokes certificates. Integration credentials remain in ignored `local.properties`; the script does not print them.

Build log: `build/device-install/reinstall.log`. If an interrupted run reports that restoration was skipped, the message identifies a backup directory containing the original files. Compare them before restoring; do not overwrite newer edits.

## Manual Terminal procedure

After completing the steps above:

```bash
cd /Users/klaskagan/code/Nuvio/NuvioMobile-Enhanced
git diff --quiet HEAD -- iosApp/iosApp.xcodeproj/project.pbxproj iosApp/iosApp/ContentView.swift
```

Stop if the last command exits nonzero: those files contain local changes. Otherwise:

```bash
git apply --check --include=iosApp/iosApp.xcodeproj/project.pbxproj --include=iosApp/iosApp/ContentView.swift build/device-install/ios-build.patch
git apply --include=iosApp/iosApp.xcodeproj/project.pbxproj --include=iosApp/iosApp/ContentView.swift build/device-install/ios-build.patch
env JAVA_HOME="$(/usr/libexec/java_home -v 21)" NUVIO_IOS_DISTRIBUTION=full \
  xcodebuild -project iosApp/iosApp.xcodeproj -target iosApp \
  -configuration Debug -sdk iphoneos \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=26NPG3Y53E \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) NUVIO_LEGACY_SDK' \
  SYMROOT="$PWD/build/device-products" OBJROOT="$PWD/build/device-intermediates" build
```

Only after `BUILD SUCCEEDED`:

```bash
codesign --verify --deep --strict "build/device-products/Debug-iphoneos/Nuvio Enhanced.app"
xcrun devicectl device install app --device 92A68FDE-123B-5A89-9955-9C95FBBFEB05 "build/device-products/Debug-iphoneos/Nuvio Enhanced.app" --timeout 120
xcrun devicectl device process launch --device 92A68FDE-123B-5A89-9955-9C95FBBFEB05 --terminate-existing com.klaskagan.nuvioenhanced --timeout 30
```

Restore the temporary adjustments afterward, including after a build failure, provided you did not edit those files meanwhile:

```bash
git apply --reverse --include=iosApp/iosApp.xcodeproj/project.pbxproj --include=iosApp/iosApp/ContentView.swift build/device-install/ios-build.patch
```

Confirm Enhanced remains open and retains its settings. Open regular Nuvio and AltStore afterward as well.

## Signing problems

Free-account provisioning normally lasts seven days. A certificate change in another sideloading tool can cause earlier failures; a future profile expiry alone does not prove the signature is still accepted by the phone. Reinstalling a build with an invalid signature may not fix it.

If the script fails at provisioning or launch, retain its log and resolve the reported signing/trust error. Do not repeatedly revoke certificates: apps installed through AltStore/SideStore may depend on them. If you reach the free-account app limit, stop rather than deleting an app with data you need.

This script is configured for this Mac, Personal Team `26NPG3Y53E`, and your paired iPhone. Set `NUVIO_REPO` or `NUVIO_DEVICE` only when their locations/identifiers change.
