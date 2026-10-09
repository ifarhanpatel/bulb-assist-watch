# Technical Spec

Public source release note (2026-10-09): this spec records the original single-bulb
product scope. Publication does not expand validated hardware support or complete
M4; see [compatibility](../compatibility.md) and [release preparation](open-source-readiness.md).

## Document Status

- Status: M1–M3 complete with owner-confirmed physical checks; merged M4 hardware and daily-use readiness in progress
- Last updated: 2026-10-09
- Owner: Farhan Patel

## Scope And Evidence

Build a personal SwiftUI Watch remote for one Wipro NS9001, with an iPhone
companion for setup. Desktop discovery, four physical API commands and restoration
passed. Direct Watch setup/control and configuration lifecycle now pass the
owner-confirmed functional checks. Interactive latency, hardware recovery and
sustained API access remain unvalidated. See [parallel validation](../validation/parallel/native-integration.md)
for current evidence and the [feasibility assessment](../research/project-feasibility.md)
for completed desktop discovery work.

Target the owner's Apple Watch Series 8, now reported on watchOS 26.6, and iPhone
17 Pro, observed on iOS 27.0. Deployment minimums are watchOS 26.0 and iOS 26.0.
Simulator gates used Xcode 26.4.1 and iOS/watchOS 26.4 runtimes; the successful
physical discovery/setup run used an active Xcode 27.0 project window.
The workspace now has Git, generated iPhone/Watch targets, shared schemes, and
the local BulbCore package. Builds use `make build`; core tests use `make test`.

### Implemented M1 Slice

`BulbRemote` maintains local selection, reported state, typed simulated failures,
and foreground-session invalidation. `SimulatedBulbController` supports normal,
slow, offline, rejected, unconfirmed, and timed-out scenarios. The adaptive Watch
screen handles Crown selection, idle delivery, on-screen power, readback, and
connection details. The M1 companion offered a simulated preview without Watch provisioning. The
integrated companion now handles acknowledged configuration and lifecycle changes.

M2 now adds intermediate pacing, power-off ordering, one shared read/write budget,
bounded confirmation, cancellation drain, and foreground reconciliation. Tuya
and companion setup are integrated with synthetic/native validation. The owner
has confirmed physical setup, relaunch persistence, fresh reads, lamp control,
key replacement, acknowledged removal and reprovisioning. M3's functional exit
passes with the manual observation limits recorded separately from automated checks.
See [parallel validation](../validation/parallel/native-integration.md).

## Implemented Architecture

```text
iPhone setup → WatchConnectivity provisioning → Watch Keychain/configuration
                                                    ↓
Watch screen → control coordinator → BulbControlling → Tuya HTTPS → NS9001
                                             ↘ simulated bulb
```

Routine control uses foreground Watch HTTPS. Phone reachability is required for
provisioning and credential changes, not for every command. This is runtime
independence after setup, not phone-free onboarding or independent App Store
distribution. No local bridge or hosted service is planned.

Use an Xcode project with iPhone and Watch app targets and one local Swift package,
BulbCore, shared by both. Use SwiftUI, Swift concurrency, URLSession, Keychain,
WatchConnectivity, and Swift Testing; no third-party runtime dependency is planned.
Keep these responsibilities distinct without creating a package per type:

| Component | Responsibility |
| --- | --- |
| Watch screen/view model | Crown focus, local display, power action, clear status |
| Control coordinator in BulbCore | Desired/reported state, serialization, pacing, lifecycle, reconciliation |
| BulbControlling | Async state read and explicit power/brightness patch submission; typed outcomes |
| SimulatedBulbController | Deterministic success, latency, offline, rejection, and stale readback scenarios |
| TuyaBulbController | HTTP contract, schema validation, raw-value conversion, safe error mapping |
| Companion setup | Key validation, device selection, provisioning and replacement status |
| Credential/configuration store | Local Keychain access and non-secret selected-device metadata |

Inject a clock and transport for deterministic tests. The adapter reports API
acceptance separately from state reads; it cannot establish that the physical
bulb changed. UI code never constructs Tuya payloads or stores credentials.
The prototype architecture is recorded in [ADR 0002](../adr/0002-watch-control-with-companion-setup.md),
with unproven assumptions explicit. This plan does not claim production integration validation.

## State And Interaction Contract

Track requested brightness, API-accepted command revision, and latest reported
state separately. Reported state includes power, raw brightness, work mode,
online status, and observation time. Give each local intent an increasing
revision; old responses cannot overwrite a newer selection or mark it complete.

Expose setup-required, connecting, stale, ready, updating, offline, timed-out,
authentication-failed, rate-limited, and command-failed outcomes. Keep the last
reported value visible as stale when appropriate. Controls require a successful
initial read; the screen must never invent an initial on/off state.

The Crown selects whole-number values from 10–100%. For the observed schema,
map selected percentage p to raw p * 10: 10 → 100, 50 → 500, 100 → 1000.
This preserves the existing UI range and smoke-test interpretation of 50%.
It is a percentage of the maximum command value, not calibrated light output.
Validate the reported 10–1000 range, step 1 and scale 0; unexpected capability
changes produce a setup error rather than a guessed mapping. Readback may report
raw 10–99; display its actual value separately from the bounded Crown selection
and do not write until the user acts.

While off, store Crown edits only in the current active session. Power-on sends
power plus edited brightness together; without an edit, send power alone to
preserve the reported setting. Power-off drops queued brightness and queues an
explicit off command after any already in-flight request. Disable repeated power
taps until the power action settles; do not queue toggles. Ignore Crown edits
during a pending power transition. If a preceding write has an uncertain outcome,
reconcile before accepting more commands.

Outside white-light mode, disable dimming and direct the user to Smart Life;
power remains available and power-on omits any brightness draft. Do not write
mode, color, or color temperature. External changes are reconciled on open,
manual refresh, and command confirmation; v1 has no continuous subscription.

## Command Scheduling And Recovery

1. Update the local selection immediately on each Crown event.
2. Keep one request in flight and only the newest pending brightness. Reads and
   writes share a scheduler so confirmation cannot flood the API.
3. While on, send intermediate values at the configured pace. On Crown idle,
   retain the final value for the next permitted send. Idle never bypasses pacing;
   a final value already sent is not sent twice.
4. Prefer pending writes over reads. After the final accepted write, perform
   bounded readback for that revision. A newer gesture supersedes older readback
   work; old responses cannot move the selected value backward.
5. Never automatically retry an uncertain write. A timeout may mean it reached
   the bulb: stop the queue, read state, and allow a fresh user action. Never
   replay old values after reconnecting.
6. On backgrounding, discard unsent intents and the off-state draft, cancel
   foreground work, and invalidate callbacks. Cancellation cannot undo a
   server-accepted write. On foreground entry, read state before enabling controls;
   an interrupted final value is not guaranteed to have been delivered.

Starting values below are implementation hypotheses, not provider limits:

| Setting | Initial value / gate |
| --- | --- |
| Simulated intermediate writes | At most 2/sec, with injected clock |
| First live request spacing | At least 1 second across reads and writes, matching probe pacing |
| Faster live dimming | Try at most 2 writes/sec only after the applicable quota permits it |
| Request timeout | 5 seconds; adjust from measured Watch behavior |
| Final confirmation | At most 2 reads within a 5-second overall confirmation window |
| Continuous polling | None |

If confirmation does not arrive, show an unconfirmed/timeout result. HTTP and
API-level rate limits stop the command queue; respect Retry-After when present,
otherwise start bounded backoff before an explicit refresh. Auth failures require
key replacement. Missing devices, offline reports, malformed data, and unsupported
schemas have actionable errors. All reads/retries share the request budget.

## Tuya Adapter Contract

Use the owner-proven helpers as fixture references and the
[Tuya End User API reference](https://www.tuya.ai/developer/docs) as the contract
(checked 2026-10-08). It specifies bearer authentication and region routing from
the key prefix; the observed region is India. Relevant routes are:

- GET /v1.0/end-user/devices/all
- GET /v1.0/end-user/devices/{device_id}/detail
- GET /v1.0/end-user/devices/{device_id}/model
- POST /v1.0/end-user/devices/{device_id}/shadow/properties/issue

The model is encoded as a JSON string and the command's properties field is also
a JSON string. Check HTTP status and the API success envelope. Match the selected
device by ID, validate its model, and issue only switch_led/bright_value patches.
Use documented HTTPS hosts only, reject redirects, and omit keys, device IDs and
raw bodies from logs. Use synthetic/redacted fixtures. The API is labeled trial;
its numeric control quota and durable access terms remain unresolved.

## Setup And Credential Lifecycle

The companion accepts the existing key in a secure field, validates it through
read-only discovery, and asks the owner to select the bulb. Persist the key in
device-local Keychain and selected-device metadata in app storage. Validate model
and mode before enabling brightness controls.

Provision while both apps are active using WatchConnectivity messaging. Include
a configuration revision, persist on Watch, and acknowledge only after the Watch's
Keychain/configuration write succeeds. A separate direct Watch read establishes
connection success. Until both pass, show setup pending or its error; sending a
message alone does not mean setup succeeded.

Replacement follows the same acknowledged flow. Never put keys in UserDefaults,
source, build settings, logs, or persistent application-context payloads. If Watch
is unreachable, show pending provisioning and retry after opening it. Local removal
deletes the phone's key and requests Watch deletion; show pending removal until
acknowledged. Local removal is not provider revocation, which remains an account
action. Check provisioning, replacement, and removal on the actual paired devices.

## Validation And Delivery

For M4, Debug connection details expose session-only coordinator read/write attempt
counts, successful write returns, matching final readbacks and the latest action
readback delay. A monotonic measurement clock starts at Crown idle/power tap.
A new gesture supersedes earlier timing; stale readback and interrupted work cannot
complete it. Reset sends no request and does not reset scheduler spacing. Counters
include failed attempts, exclude discovery/model checks, and contain no device
metadata or credentials. They are neither physical-latency evidence nor provider
billing counts; visible response is measured separately in the hardware run sheet.

Use Swift Testing for shared-core behavior and mocked HTTP contracts. Cover
latest-value delivery, stale-response protection, request bounds, power-off
ordering, off-state drafts, mapping, interruption, rate limits, schema rejection,
and safe errors. Distinguish API acceptance from matching readback. Live tests
are manual and never part of routine unit tests.

Build both targets and exercise the simulator, then use the owner's devices for
signing, Crown feel, credential transfer, and direct HTTPS. The
[delivery plan](tasks.md) defines order and measurable exits.

The merged M4 includes hardware validation, at least three days of normal-use
observations, provider-access checks and maintenance documentation. The remaining
real-device gate covers ordinary dimming gestures and 10 power actions: all final values
visibly reached within two seconds of stopping under normal connectivity, no
later rollback, and all power outcomes correct. Record acceptance, cloud readback,
and visible response separately. Assess intermediate dimming while turning;
final-value-only behavior does not by itself pass continuous dimming acceptance.
If targets fail, tune or make an explicit scope decision. On 2026-10-09 the owner
deferred endpoint and reversal checks, choosing to report any problems later as
issues; do not claim physical validation of those interactions.

Test background/reopen, bulb and Watch internet loss, external Smart Life changes,
invalid credentials, and an unreachable iPhone with Watch internet. Daily-use
readiness also requires known key lifetime/quota/access terms and an understood
signing/reinstallation workflow.

## Platform References

- [Apple Crown input APIs](https://developer.apple.com/documentation/swiftui/input-events/): bounded bindings and idle callbacks support local feedback and final dispatch.
- [Apple foreground requests](https://developer.apple.com/documentation/watchos-apps/making-default-and-ephemeral-requests): foreground requests require lifecycle handling.
- [Apple WatchConnectivity messaging](https://developer.apple.com/documentation/watchconnectivity/wcsession/sendmessage(_:replyhandler:errorhandler:)): activated-session messaging can fail when the counterpart is unreachable.

These APIs support the planned mechanisms; they do not establish physical Watch
latency or guarantee successful provisioning for this project.
