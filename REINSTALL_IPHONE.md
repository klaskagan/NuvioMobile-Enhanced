# Reinstall Nuvio Enhanced on your iPhone

This installs over `com.klaskagan.nuvioenhanced`, preserving its app data. Do not delete Enhanced first. Regular Nuvio uses a different identifier and remains installed.

## Before starting

1. Connect the iPhone by USB and keep it unlocked and online.
2. On the phone, open **Settings → General → VPN & Device Management**. If your developer account offers **Trust** or **Verify App**, complete that and try Enhanced again.
3. In **Xcode → Settings → Apple Accounts**, confirm your account shows **Personal Team**. Complete sign-in yourself if requested.
4. Close the Nuvio project in Xcode.

## One-command installation

```bash
bash /Users/klaskagan/code/Nuvio/NuvioMobile-Enhanced/reinstall-nuvio-enhanced.sh
```

To validate the local prerequisites without building or touching the phone:

```bash
bash /Users/klaskagan/code/Nuvio/NuvioMobile-Enhanced/reinstall-nuvio-enhanced.sh --check
```

Run from the `develop` branch with its committed MPVKit revision checked out. The script backs up matching cached Nuvio profiles so Xcode requests fresh ones, builds and verifies the signature, checks the app and widget profile expirations, then installs and launches over the existing app.

Build log: `build/device-install/reinstall.log`.

## Signing problems

Free-account provisioning normally lasts seven days. A certificate change in another sideloading tool can cause earlier failures; a future profile expiry alone does not prove the signature is still accepted by the phone. Reinstalling a build with an invalid signature may not fix it.

If the script fails at provisioning or launch, retain its log and resolve the reported signing/trust error. Do not repeatedly revoke certificates: apps installed through AltStore/SideStore may depend on them. If you reach the free-account app limit, stop rather than deleting an app with data you need.

This script is configured for this Mac, Personal Team `26NPG3Y53E`, and your paired iPhone. Set `NUVIO_REPO` or `NUVIO_DEVICE` only when their locations/identifiers change.
