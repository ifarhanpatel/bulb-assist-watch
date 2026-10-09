# Stream C — companion setup and provisioning

Validated 2026-10-09, based on shared contracts commit `0ffaaea` in isolated
worktree `/private/tmp/bulb-assist-stream-c`, branch `codex/m3-companion-setup`.
The handoff commit is supplied to the integration owner with this report.
VoiceOver work remains excluded. No API key or physical lamp was used.

## Implementation

- `CompanionSetup` implements secure key entry discovery, explicit selection and
  capability validation, local persistence, Watch persistence acknowledgement,
  then separate direct Watch verification. Replacement validates before replacing
  local storage. Removal deletes the phone key first and remains pending until a
  matching Watch deletion acknowledgement arrives.
- Revision tombstones survive deletion/relaunch. Duplicate provision/remove
  messages are idempotent; conflicting duplicates and stale revisions fail.
  Generation guards prevent late replies from restoring a removed configuration.
  Relaunch conservatively re-establishes persistence/direct-read evidence; a
  tombstone conservatively repeats removal until another durable acknowledgement.
- `ProvisioningReceiver` serializes whole operations, including direct read,
  invalidation, persistence and replies. Replacement/removal invalidate the old
  remote before storage changes. Persistence callbacks run only after durable
  success. Only a successful online direct read returns `connected`.
- `KeychainCredentialStore` stores one atomic configuration/tombstone record with
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, synchronization disabled. No
  UserDefaults, production logging, raw error descriptions, or persistent
  WatchConnectivity context contains credentials.
- `WatchConnectivityBridge` uses active `sendMessage` request/reply only, validates
  acknowledgement revision, reports reachability/activation without payloads,
  and bounds waiting to 15 seconds. Cancellation/late callbacks complete at most
  once. It never uses transferUserInfo or updateApplicationContext.
- `SetupView` follows the Pen phone flow with native typography, scrolling,
  54-point primary actions, secure field, key guidance, connection settings,
  replacement and removal confirmation, pending states and actionable errors.
  `WelcomeView(prototype:setup:)` exposes setup alongside the original prototype.

## Validation

All commands ran inside the isolated checkout with its own `build/` directories:

- `make test`: **40 tests passed**, including **24 setup lifecycle tests**.
  Coverage includes invalid keys, empty discovery, authentication/network errors,
  cancellation, unsupported models, failed storage, interruption, unreachable
  Watch, persistence/read separation, premature success, stale persistence/read/
  deletion replies, replacement, removal, relaunch, duplicate/conflicting messages,
  tombstones, invalidation ordering and serialized read/removal.
- `make build-watch`: **BUILD SUCCEEDED** with all new platform sources included.
- `make build-iphone`: **BUILD SUCCEEDED** with setup/settings UI included.
- `xcodebuild -project BulbAssist.xcodeproj -scheme BulbAssist -destination
  'generic/platform=iOS Simulator' -derivedDataPath build/iPhone
  CODE_SIGNING_ALLOWED=NO build-for-testing`: **TEST BUILD SUCCEEDED**.
  Compiles seven added native tests for Keychain store/load/replace/delete,
  relaunch/stale replay, device-only protection, credential-free tombstone,
  native receiver lifecycle, active-message codec and one-shot reply/cancellation.
- Native test **execution** and phone UI screenshots remain the integration
  owner's serialized simulator gate. No simulator was installed/launched here.
  Paired-device delivery, signing and physical lamp checks remain the M3 gate.

Root authorized temporary local project regeneration for source visibility.
Generated project changes are restored before committing; the root must regenerate
its integrated project before compiling the new phone navigation entry. Logs are
local ignored `build/logs/` files and are not part of the commit.

## Integration recipe

Keep app construction and shared Watch views in the integration checkout.
Regenerate the integrated project to include all new owned source directories and
`Tests/PlatformTests/ProvisioningPlatformTests.swift` (`@testable import BulbAssist`).
No Package.swift, project.yml or Makefile changes are required by this stream.

Phone:

```swift
let store = KeychainCredentialStore()
let bridge = WatchConnectivityBridge(onStateChange: { /* retry pending stages */ })
let setup = CompanionSetup(store: store, messaging: bridge) { key in
    try TuyaDiscovery(apiKey: key)
}
// Retain bridge; call bridge.activate(). The root callback should retry only
// awaitingWatch/pendingRemoval stages, avoiding repeated successful checks.
WelcomeView(prototype: prototype, setup: setup)
```

`SetupView` calls `restore()` and `retryDelivery()` on entry. Fixture construction
can inject `FixtureDiscovery`, `MemoryCredentialStore` and
`LoopbackMessageTransport(receiver:)`; fixture IDs default to `fixture-bulb`.

Watch:

```swift
let receiver = ProvisioningReceiver(
    store: watchStore,
    controllerFactory: { configuration in /* return coordinated direct-read proxy */ },
    invalidate: { /* await oldRemote.deactivateAndWait() */ },
    configurationChanged: { configuration in /* rebuild/remove configured remote */ }
)
let bridge = WatchConnectivityBridge(receiver: { message in
    await receiver.receive(message)
})
bridge.activate()
```

Root must also restore the configured Watch remote from Keychain on launch.
A duplicate persistence message does not repeat the configurationChanged callback.
The controller factory must use the same remote/coordinator as foreground control,
so setup verification cannot overlap a remote request. Root has chosen a proxy
through remote.refresh(), with lifecycle drain on invalidation and live spacing
between Tuya model validation and the first reported-state read.

Phone UI identifiers: `apiKeyField`, `discoverDevicesButton`, each selected-device
button uses `device.id`, `connectionSettingsButton`, `replaceKeyButton`, and
`removeConnectionButton`. ConfirmationDialog destructive button is **Remove**.
Titles: `Ready when\nyou are.`, `Finish on\nyour Watch`, `Connection removed`.
Invalid-key guidance begins **Check your API key.** The settings destination
renders the new setup stage when replacement or removal changes it.

## Settings navigation regression fix

The integration owner's native UI gate found that a cached `AnyView` settings
navigation destination retained its initial connected screen after Replace API
key. The destination now creates an observable `SetupView` instance that tracks
stage changes in its own body. Its task never restores stored configuration over
a replacement in progress. The root setup view restores only once per lifetime,
and presentation uses a stable navigationDestination modifier so replacing the
connected screen cannot remove the navigation source and dismiss the flow.

After this fix: `make test` passed all 40 tests; `make build-watch` and
`make build-iphone` both passed. Native UI runtime rerun remains with integration.
No extra pure test was added because the defect is in native navigation rendering,
which the existing integration UI journey exercises directly.
