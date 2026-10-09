# Setup

## Requirements and simulator run

Use full Xcode with Swift 6 and iOS/watchOS 26 or newer SDKs and simulator
runtimes. Command Line Tools alone cannot build the apps. The deployment
minimums are 26.0. Release preparation used Xcode 27.0 with 26.4 runtimes.
Select your installed Xcode in **Xcode → Settings → Locations**, and install
missing runtimes from Xcode's Components settings.

Open `BulbAssist.xcodeproj`. Use the **BulbAssist** iPhone scheme and select
**Try the prototype**, or add `--prototype` to the **BulbAssistWatch** scheme's
Run arguments. No key, account, bulb or signing team is required in the simulator.

```sh
make test                 # BulbCore package tests
make build                # Both simulator applications
make test-platform        # Keychain and provisioning contracts
make test-iphone-ui       # Companion fixture flows
make test-watch-ui        # Watch fixture and prototype flows
```

Run simulator tests one command at a time. Defaults are `iPhone 17 Pro` and
`Apple Watch Series 11 (46mm)`. List installed devices with `xcrun simctl list devices available`
and override the destinations if needed:

```sh
make test-platform IPHONE_DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro'
make test-watch-ui WATCH_DESTINATION='platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

Build output and result bundles live under ignored `build/`. `make generate`
requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.42.0 or newer; run it
when changing `project.yml` or adding/removing project source files. It is not
required for a normal checkout build.

## Your signing configuration

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Edit the copy with your own Apple development team ID and unique reverse-domain
bundle prefix. For example, the placeholder prefix `com.yourname` produces
`com.yourname.BulbAssist` and `com.yourname.BulbAssist.watchkitapp`.
Replace it with a namespace you control. The Watch companion identifier derives
from the same prefix. The default `org.example` is for simulator development.

`Config/Local.xcconfig` is ignored and optional. Do not enter an API key there,
in Xcode build settings, a launch argument, a plist, or a committed environment
file. Let Xcode manage signing for your own devices. Install the companion and
Watch app on paired devices running iOS/watchOS 26 or newer. Apple account
provisioning and signing limits apply to your installation.

## Live setup

1. Pair your owned bulb with Smart Life using the bulb's supported instructions.
   It must appear in the account linked to your End User API key. Wipro Next
   membership alone does not establish visibility in that account.
2. Read the [Tuya End User API reference](https://www.tuya.ai/developer/docs) and
   use its official **Get API Key** path. Review the account and feature terms
   shown there before accepting them. This app expects an End User bearer key,
   not an IoT Core cloud-project Client ID/Secret or a local LAN device key.
3. On iPhone choose **Set up my bulb**, enter the key in the secure field and
   discover devices. Select a bulb matching the [supported schema](compatibility.md).
4. Keep the paired Watch app active/reachable while provisioning. Wait for the
   Watch storage acknowledgement; then verify a fresh read from the Watch.
   An acknowledgement of storage is not proof of cloud connectivity.
5. Select white mode using Smart Life before adjusting brightness. Start with
   ordinary, supervised power and dimming gestures.

API eligibility, limits and future charges are controlled by Tuya. This project
does not promise free permanent access or a particular quota. Never use another
person's credentials or grant the app access to devices you are not authorized
to control. A key may authorize more devices than the one selected in this app.

## Replacement, removal and recovery

Use the companion's connection settings to replace a key or remove the
connection. Keep the Watch reachable until it acknowledges the update/removal.
Pending removal means its stored key may still be present. Local removal retains
a revision tombstone to reject stale messages; it does not revoke the provider key.
Revoke a compromised or unwanted key through Tuya's account/key management.
Do not rely on uninstalling the app to revoke access or erase Keychain items.

For offline, invalid-key or cooldown states follow the displayed recovery action.
Do not repeatedly retry during rate limiting. The Debug prototype offers
simulated recovery states and **Measurements**; its counters measure requests and
readback delays, not physical lamp latency.

## Optional diagnostic scripts

Python 3 and Bash are required for the diagnostic helpers. Publication tooling
uses Python 3.9 or newer. `scripts/check-tuya-api.sh`
performs read-only discovery; `scripts/test-tuya-control.sh` performs real power
and brightness changes after its interactive prompts. Do not run the latter
without supervising the lamp. Neither script is part of CI.

Enter the key only at the hidden prompt. Do not pass it in command arguments or
share a terminal recording: device names may appear during selection. Reports
default to ignored `build/reports/`. They omit keys and device IDs, but can include
region, timestamps and state. Inspect every report before sharing it; read
[PRIVACY.md](../PRIVACY.md) for the complete data flow.
