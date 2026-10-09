# Delivery Tasks

Last updated: 2026-10-09. M1–M3 are complete. The owner has confirmed the guided
physical setup, control, relaunch and key lifecycle checks. On 2026-10-09 the owner
merged M4 and M5 into M4 — Hardware And Personal Daily-Use Readiness, which remains
open.
Open-source release preparation is tracked separately in the
[readiness plan and checklist](open-source-readiness.md); it does not mark the
remaining physical M4 checks complete.
See [parallel validation](../validation/parallel/native-integration.md)
and [M1 history](../validation/m1-simulator.md).
Validate milestone exits in order, keeping each result runnable and reviewable.
The [parallel implementation plan](parallel-delivery-plan.md) allows M3 adapter
and companion work with fixtures alongside M2 after shared contracts are agreed;
live M3 validation still depends on M2 completion.
Requirements refer to [product-spec.md](product-spec.md); implementation contracts
and initial tuning values are in [technical-spec.md](technical-spec.md).

## Design Implementation Map

Use the [design previews](../../design/README.md) and
[design handoff](../../design/review.txt) as the visual and interaction references.
The 15 Watch layouts represent states of the remote and its connection details;
implement shared views driven by state rather than a separate view for every mockup.
The iPhone screens form one setup/settings flow without a tab bar.

| Milestone | Design coverage |
| --- | --- |
| M1 | W01 confirmed remote, W03 off, W04 local selection, W14 compact, W15 larger text |
| M2 | W02 adjusting, W05 pending power, W07 connecting, W08 offline, W09 unconfirmed, W12 cooldown, W13 details/refresh |
| M3 | P01–P06 setup/settings, P07 key error, P08 replacement, P09 removal; W06 setup and W10 key recovery; W11 non-white mode |
| M4 | Hardware usability and lifecycle transitions, sustained-use observations, and final setup/maintenance documentation |

Use native SwiftUI typography, safe areas, navigation, and adaptive scrolling.
Preserve the Pen design's hierarchy, amber accent, labels, and agreed behavior.
Keep title/back/reveal-key hit regions usable and text/layout readable.
The decorative brightness arc must not carry essential information. Per the
owner's 2026-10-09 direction, dedicated VoiceOver work and accessibility audits
are out of scope; add accessibility work only for a verified applicable Apple
requirement. Existing readable layouts and native control metadata can remain.

## Completed Baseline

- [x] Define one-user, one-bulb Apple Watch scope and SwiftUI application shape.
- [x] Prove Smart Life pairing and phone/cloud control.
- [x] Prove API discovery, schema, four physical commands, and restoration.
- [x] Identify hardware: Apple Watch Series 8 on watchOS 26.3; iPhone 17 Pro.
- [x] Choose off-state behavior: Crown selects locally; power button turns on.
- [x] Create the Pen UI/UX canvas, previews, and design handoff in the project.

## M1 — Runnable Watch Interaction

Outcome: open one Watch screen, rotate the Crown, and use power against a simulated
bulb. Requires no API key or physical-bulb access.

- [x] Initialize Git with suitable ignores and create the Xcode iPhone/Watch
  targets plus shared BulbCore package. Use proposed iOS/watchOS 26.0 minimums.
  (FR6, FR7, QR4)
- [x] Install a compatible watchOS simulator runtime and record reproducible
  build/test commands and shared schemes. (supports FR1–FR12, QR4)
- [x] Record an ADR for the prototype's direct Watch REST path, companion setup,
  adapter boundary, and remaining validation conditions. (FR6, FR9, FR10)
- [x] Define shared bulb snapshots, typed errors, explicit command patches, and
  BulbControlling. (FR1, FR2, FR5, FR6)
- [x] Add deterministic online, slow, offline, failed, and unconfirmed simulated
  states. (FR5, FR7, QR4)
- [x] Build bulb name, brightness, power, status, Crown focus, and clear
  labels on one screen. Implement local off-state selection. (FR1–FR3, FR8, QR1, QR2)
- [x] Translate the main, off, and local-selection designs into one adaptive
  SwiftUI remote. Check compact and larger-text layouts before adding live API
  control. (FR1–FR3, FR8, QR1, QR2)
- [x] Test mapping and off-state behavior; build both targets and run the
  simulated journey in the Watch simulator. (FR2, FR7, FR8, QR4)
- [x] Verify on-state Crown dimming and scroll the larger-text recovery screen
  to its action in the native simulator. (QR1, QR2)
- [x] Complete draft application with Turn on and Crown focus after connection
  details and both power actions. Four functional Xcode UI tests pass on the
  Series 8 45mm simulator, including larger-text recovery scrolling. (QR1, QR2)

Exit: immediate display changes, bounded 10–100% input, no power change on Crown
rotation while off, and visible simulated failures. Power taps preserve Crown
usability. Record builds/tests; simulator results do not pass physical-device gates.

## M2 — Correct Command Behavior

Depends on M1. Outcome: rapid input stays responsive, requests remain bounded,
and the newest selected value wins.

- [x] Separate requested, API-accepted, and reported state with revision checks.
  (FR3, FR5)
- [x] Add one-request serialization, latest pending value, intermediate pacing,
  final idle delivery, deduplication, and bounded confirmation. (FR4)
- [x] Implement power-off ordering, blocked repeat power taps, and draft
  application on power-on. (FR1, FR8)
- [x] Handle uncertain writes, timeouts, rate limits, background cancellation,
  and foreground reconciliation without replay. (FR5, FR11)
- [x] Connect the pending/recovery designs to actual coordinator outcomes and
  implement connection details with explicit refresh and Crown focus restoration.
  (FR3, FR5, FR11, QR1, QR2)
- [x] Test bursts, slow responses, obsolete readback, duplicate idle, power-off
  during dimming, backgrounding during writes, and failed confirmation with a
  fake clock; assert outcomes and request bounds. (FR4, FR5, FR8, FR11, QR4)

Exit: deterministic tests prove one in-flight request, bounded pending work, no
obsolete UI rollback, and final delivery under normal simulated connectivity.
Interruption and failed confirmation remain visible as unconfirmed outcomes.

## M3 — First Live Watch Control

Depends on M2. Outcome: enter the key on iPhone, select the bulb, provision Watch,
then control the physical lamp from Watch.

- [x] Implement Tuya discovery, detail, model parsing, and property commands.
  Test endpoint/payload/envelope behavior using redacted fixtures derived from
  the proven helpers. (FR1, FR2, FR6)
- [x] Enforce schema checks and white-mode dimming; preserve color temperature
  and reported brightness when no new value is chosen. (FR2, FR8, FR12)
- [x] Build companion key entry, device selection, verification, provisioning
  status, and actionable errors. (FR9, QR3, QR5)
- [x] Add local Keychain storage and acknowledged WatchConnectivity provisioning,
  replacement, and removal. Test interrupted/unreachable setup and confirm logs
  and fixtures contain no keys. (FR9, QR3, QR5)
- [x] Identify actual device versions and private signing team; sign/install both
  apps and expose the real Watch as a run destination. iPhone reports iOS 27.0;
  owner reports Series 8 on watchOS 26.6. (FR9)
- [x] Obtain owner confirmation that real Watch setup and physical lamp control
  work. See the physical-run evidence and its observation limits. (FR1, FR2, FR9)
- [x] Obtain owner confirmation that configuration survives relaunch on both
  devices and a fresh Watch read matches the lamp without changing it. (FR9)
- [x] Obtain owner confirmation that physical key replacement, acknowledged
  removal and reprovisioning work. Record application acceptance evidence,
  reported state and physical observations separately, identifying inference
  and the absence of independent HTTP captures. (FR1, FR2, FR9)

Exit: setup survives relaunch on both devices, Watch reads directly, and live
commands visibly work. Document signing/reinstallation. Start with the technical
spec's live pacing; no claim of smooth dimming yet.

## M4 — Hardware And Personal Daily-Use Readiness

Started 2026-10-09: Debug measurement counters/readback timing and a staged
[hardware run sheet](../validation/m4/hardware-run.md) are prepared. All physical
acceptance items below remain open until their observations are recorded. The
owner deferred endpoint and reversal checks on 2026-10-09 and will raise an issue
if problems arise in use; those checks are not required for the remaining M4 exit.

Depends on M3. Outcome: a documented build the owner can use and maintain, with
responsive Series 8 control, honest recovery and sustainable access. Former M5
work is included here; there is no separate M5 gate. Hardware checks and provider
clarification can run alongside the three-day use observations.

- [ ] Measure the remaining ordinary Crown gestures and 10 power actions.
  Endpoint and reversal trials are deferred by owner decision. Record median/worst
  visible delay, readback timing, request counts, and any late rollback. (FR1–FR4, QR2)
- [ ] Assess intermediate dimming; tune sensitivity, haptics, pacing, and
  confirmation. Check the applicable quota before faster writes. Final-value-only
  fallback requires an explicit scope decision. (FR3, FR4, QR2)
- [ ] Check off-state selection, power-off during dimming, and externally reported
  brightness below 10%; opening the app must not change the lamp. (FR2, FR8)
- [ ] Test Watch internet loss, bulb offline, background/reopen, stale readback,
  invalid key, and rate limiting. Inject failures that cannot reliably be induced
  live. Verify no old dimming requests replay. (FR5, FR11)
- [ ] Change the bulb through Smart Life and refresh: reconcile power,
  brightness, and non-white mode correctly. (FR11, FR12)
- [ ] Make iPhone unreachable while Watch retains internet; repeat power and
  brightness control. Provisioning still requires the phone. (FR10)

- [ ] Record actual quota, key lifetime/replacement, mobile-use conditions, and
  continuing access/cost terms from the account/provider. (supports FR4, FR9, FR10)
- [ ] Use across normal sessions on at least three days; record failures, request
  volume, and observable battery/latency concerns. This proposed observation
  window is not a reliability certification. (FR1–FR5, FR10, FR11)
- [ ] Verify key replacement/removal and recovery after reinstall; document setup,
  rebuilding, reprovisioning, and known limits. (FR9, QR3, QR5)
- [ ] Update specs/ADR and save redacted Watch acceptance results with device/OS
  versions, build version, tuning values, and outcomes. (QR3, QR4)

Exit: tested ordinary-gesture final values visibly reach their target within two
seconds of stopping, with no later rollback; 10/10 power outcomes are correct;
intermediate dimming, recovery and phone-unreachable checks pass. Record normal
use across at least three days, complete maintenance documentation and establish
sustainable access/signing requirements. These are prototype targets; record
misses before deciding how to proceed. Endpoint/reversal checks remain deferred.
Unknown provider terms retain experimental-prototype status; they do not block
M1/M2 implementation.

## Effort And Definition Of Done

The feasibility estimate of 3–7 development days after API proof remains a rough
budget for implementation and hardware work if setup/signing go smoothly. The
merged M4 also includes the three-day use observations. Runtime downloads, device
troubleshooting and provider clarification can add elapsed time.
Re-estimate after the first live Watch run; no calendar deadline is set.

- Every behavior maps to requirements and relevant spec changes.
- Automated checks cover meaningful state/contract behavior without live keys.
- Build/simulator results and physical observations are recorded separately.
- Check a milestone off only after its exit evidence is recorded.
- M1–M3 and combined native implementation evidence are saved. M3 passes through
  owner-confirmed functional checks; merged M4 measurements, recovery, sustained-use
  and maintenance evidence remain open.
