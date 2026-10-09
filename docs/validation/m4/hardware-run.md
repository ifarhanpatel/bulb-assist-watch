# M4 hardware and personal daily-use readiness — started 2026-10-09

Status: measurement tooling and run sheet prepared; physical and daily-use evidence
pending. The owner merged M4 and M5 on 2026-10-09. This record now covers the
combined M4; hardware checks can be recorded alongside normal-use observations.
M3 is owner-confirmed. No M4 physical result is inferred from simulator success.
VoiceOver remains outside scope. On 2026-10-09 the owner deferred endpoint and
reversal acceptance checks and will raise an issue if those interactions cause
problems in use. Deferred checks have no physical pass evidence.

## Build and conditions

Baseline: `b5c3c13` plus the M4 measurement changes in this working tree.
Install the Debug BulbAssistWatch scheme on the paired Series 8 using the existing
private signing configuration. Leave prototype/fixture launch arguments disabled.
Record the tested commit/build after installation; do not enter API credentials here.

| Field | Run value |
| --- | --- |
| Watch | Series 8; confirm size and current OS (last owner report: watchOS 26.6) |
| iPhone | 17 Pro; confirm current OS (last device report: iOS 27.0) |
| Tested build/commit | Pending |
| Internet path | Pending: Watch Wi-Fi/cellular/phone-assisted connectivity |
| Bulb | Wipro NS9001, powered and online, white mode |
| Starting lamp power/brightness | Record before each trial |
| Crown | Medium sensitivity, whole 10–100% steps, native haptics enabled |
| Live policy | At least 1 s between read/write starts, 5 s request timeout |
| Confirmation | At most 2 reads in a 5 s window |
| Provider quota | Unknown; retain current live pacing |

## Measurement procedure

1. Open the configured Watch remote and wait for its fresh read. Confirm the lamp
   and screen agree. Opening alone must not change the lamp.
2. Tap the bulb title → **Measurements**, then **Reset counts** while idle. Return
   to the remote using both back buttons. Reset sends no request and preserves pacing.
3. Perform one trial. For a gesture, start visible-response timing when your hand
   stops rotating the Crown; for power, start at the tap. A video showing both
   Watch and lamp gives better evidence than an estimated delay. Mark estimates.
4. Note the final displayed target, whether the lamp changes during rotation,
   visible final delay, and any later rollback during at least 5 s of observation.
   Watch the lamp throughout, including when opening Measurements.
5. Once work settles, open Measurements and transcribe reads, writes, API accepted,
   matching reads, last action/result and readback delay. Screenshot if useful.
   Reset before the next trial. Record errors and misses; do not silently rerun them.

**Counts** are coordinator operation attempts, including failed/cancelled requests,
not server-side receipt or billing counts. Setup discovery/model checks are excluded.
**API accepted** counts successful write returns; timed-out or uncertain operations
remain unproven even if the lamp changes. **Matching reads** count final-revision
confirmations, not all reads. Readback timing starts at the SwiftUI Crown idle
callback or accepted power tap; Crown idle occurs after physical rotation stops.
It therefore cannot substitute for the two-second physical timing target.
Navigation and Reset do not poll. App reactivation does read; record such reads
if a trial was interrupted. Counts last until reset or remote reconstruction;
only the latest action is shown. This is a transcription aid, not a persistent trace.

If the lamp reaches its target before rotation stops, record visible final delay
as 0 s. Do not guess a timing for indistinguishable light levels. Record exact
selected endpoints even when a planned approximate percentage differs.

## Crown trials — endpoint and reversal checks deferred

Keep the lamp on in white mode. Reach each starting value as preparation, wait
for reported confirmation, then reset counters. Preparation requests are excluded.
Each row is one distinct uninterrupted gesture; pauses can trigger Crown idle.
The remaining ordinary-gesture trials are G01, G02, G06, G07, G08, G12, G13,
G14, G18 and G20. Start with G01/G02. Deferred rows remain for historical context.

| ID | Planned gesture (%) | Final target | Visible delay (s) | Readback (s) | Reads / writes / accepted / matching | Intermediate dimming | Late rollback | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| G01 | 50 → 70, slow | | | | | | | Pending |
| G02 | 70 → 30, slow | | | | | | | Pending |
| G03 | 30 → 100, endpoint | | | | | | | Deferred by owner |
| G04 | 100 → 10, endpoint | | | | | | | Deferred by owner |
| G05 | 10 → 80 → 40, reversal | | | | | | | Deferred by owner |
| G06 | 40 → 60, short | | | | | | | Pending |
| G07 | 60 → 20, brisk | | | | | | | Pending |
| G08 | 20 → 90, brisk | | | | | | | Pending |
| G09 | 90 → 30 → 70, reversal | | | | | | | Deferred by owner |
| G10 | 70 → 10, endpoint | | | | | | | Deferred by owner |
| G11 | 10 → 100, slow full range | | | | | | | Deferred by owner |
| G12 | 100 → 50, slow | | | | | | | Pending |
| G13 | 50 → 55, small change | | | | | | | Pending |
| G14 | 55 → 45, small change | | | | | | | Pending |
| G15 | 45 → 80 → 20, reversal | | | | | | | Deferred by owner |
| G16 | 20 → 100, brisk endpoint | | | | | | | Deferred by owner |
| G17 | 100 → 10, brisk endpoint | | | | | | | Deferred by owner |
| G18 | 10 → 60, slow | | | | | | | Pending |
| G19 | 60 → 20 → 90, reversal | | | | | | | Deferred by owner |
| G20 | 90 → 50, normal | | | | | | | Pending |

Summary pending for the remaining ordinary gestures: targets visibly reached
≤2 s after rotation stops, median
and worst visible delay, median and worst reported confirmation delay, request
volume, intermediate dimming judgement, zero late rollback. Record completed trial values
before computing summaries; exclude deferred trials and report sample size. If intermediate dimming is unacceptable, record the
problem before tuning. Faster writes need quota evidence; final-value-only behavior
requires an explicit owner scope decision.

## Ten power trials

Prepare the lamp on. Alternate off/on; wait for settlement and reset between rows.
Count only the tap, not preparation. For P04 and P08, edit locally while off before
resetting; verify those edits caused zero writes and no lamp change. Power-on
should apply the draft; on other on-trials it preserves reported brightness.
For P09, start a dimming gesture before tapping off and include those writes in
that row. Verify discarded queued values never turn it back on.

| ID | Action | Expected | Visible delay (s) | Readback (s) | Reads / writes / accepted / matching | Observed lamp and reported state | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P01 | Off | Off | | | | | Pending |
| P02 | On, no draft | On, brightness preserved | | | | | Pending |
| P03 | Off | Off | | | | | Pending |
| P04 | On, 30% local draft | On at 30% | | | | | Pending |
| P05 | Off | Off | | | | | Pending |
| P06 | On, no draft | On at 30% | | | | | Pending |
| P07 | Off | Off | | | | | Pending |
| P08 | On, 80% local draft | On at 80% | | | | | Pending |
| P09 | Off during dimming | Off, no later queued dimming | | | | | Pending |
| P10 | On, no draft | On, reported brightness preserved | | | | | Pending |

Summary pending: 10/10 correct physical outcomes, median/worst visible and readback
delay, request counts, repeated taps blocked, Crown focus returns after power.
The two-second exit threshold applies to dimming; report power delay separately.

## Recovery and independent Watch checks

Perform these after the normal-connectivity batch, recording actual observations.
Restore normal conditions and explicitly refresh before continuing each check.

| Check | Procedure and expected result | Evidence / result |
| --- | --- | --- |
| Off-state selection | Turn off, reset, rotate. Lamp stays off, write count stays zero. Reopen: draft discarded, fresh reported value shown. | Pending hardware |
| Below-range report | Set brightness below 10% through Smart Life if supported; refresh Watch. Actual report remains visible, opening/refresh sends no corrective write. Otherwise use `--below-range` simulation and label it injected. | Pending |
| Background during dimming | Rotate, leave the app while updating, then reopen. Fresh read before controls; unsent old values never replay. An already accepted write may still reach lamp. | Pending hardware |
| External white-mode changes | Change power and brightness in Smart Life; Watch refresh agrees without overwriting those changes. | Pending hardware |
| Non-white mode | Select color in Smart Life; refresh. Dimming disabled, power available, mode/temperature not changed by Watch. Restore white mode. | Pending hardware |
| Bulb offline | Disconnect bulb power or its internet. Attempt control: offline/unconfirmed failure, never false confirmation. Restore then refresh; no old intent replay. | Pending hardware |
| Watch internet loss | Remove all Watch internet routes (including Bluetooth phone fallback); attempt control. Clear failure, then fresh reconciliation after recovery, no replay. Record actual route isolation. | Pending hardware |
| iPhone unreachable | Disable phone connectivity/power while Watch retains its own Wi-Fi/cellular. Confirm Watch internet with a fresh read, then one power cycle and brightness change. Setup still needs phone. | Pending hardware |
| Stale readback | Use prototype `--scenario=unconfirmed`. Final stays unconfirmed after bounded reads. Also covered by coordinator obsolete-response tests; this is injected evidence. | Pending injection |
| Invalid key | Use prototype `--scenario=authenticationFailed`. Key-replacement prompt, controls blocked. Do not replace a working key solely to induce this check. | Simulator launch/prompt/control-block check passed; hardware not claimed |
| Rate limit | Use prototype `--scenario=rateLimited`. Stop queue; after cooldown select Connected in simulation picker and explicitly Refresh. Never induce quota exhaustion on live bulb. | Pending injection |
| Uncertain write | Use prototype `--scenario=uncertainWrite`. Reconcile before fresh action; no automatic write replay. | Pending injection |

Injected tests verify deterministic handling; they do not establish provider behavior
on hardware. Keep physical, simulator, and unit evidence separate. Prototype uses
simulation and never loads the live bulb credentials.

## Daily-use observations

Use across normal sessions on at least three days. Record actual dates; this is
an observation window, not a reliability certification. Hardware and recovery
checks above can be completed during these sessions; keep injected results labeled.
Raise issues for problems encountered, including deferred endpoint/reversal behavior.

| Day | Date / tested build | Sessions and request counts | Failures / issue references | Battery / latency observations | Hardware checks completed |
| --- | --- | --- | --- | --- | --- |
| 1 | Pending | | | | |
| 2 | Pending | | | | |
| 3 | Pending | | | | |

## Provider access and maintenance

| Item | Evidence / result |
| --- | --- |
| Actual quota and rate limits | Pending account/provider evidence; retain current live pacing |
| Key lifetime and replacement | Pending; record behavior and terms without recording the key |
| Mobile-use conditions and continued access/cost | Pending account/provider evidence |
| Signing and reinstall workflow | Pending final documentation |
| Replacement/removal and recovery after reinstall | Pending M4 check; M3 functional key-lifecycle checks already owner-confirmed |
| Setup, rebuild and reprovisioning instructions | Pending final documentation |
| Known limits and redacted final evidence | Pending specs/ADR update, device/OS versions, tested build, tuning and outcomes |

Unknown provider terms retain experimental-prototype status. Combined M4 remains
open until its hardware, observation, access and maintenance evidence is recorded;
merging the milestones does not establish a passing result.

## Automated preparation evidence

- `make test`: **89 tests in 7 suites passed**, including 4 measurement/injected-auth
  tests. Coverage includes actual attempts versus accepted writes, repeated idle
  preserving the timing origin, reset preserving live pacing, superseded readback,
  interrupted work and uncertain-write reconciliation. The existing stale-read
  timeout test now also asserts that newer measurement remains pending, then confirms.
- `make build`: **both simulator apps passed**, strict Swift 6 concurrency. Only
  the existing skipped AppIntents metadata warning appeared.
- `make test-watch-ui`: **9 tests passed**, zero failures, 181.145 s. Includes
  measurement counters, reachable reset, and returning to an unchanged off bulb,
  plus configured launch, Crown focus, cooldown, larger-text recovery, foreground
  reconciliation and power-off during dimming.
- Focused invalid-key native test: **1 test passed**, zero failures, 8.570 s.
  The injected authentication failure shows key replacement and blocks remote
  controls. This supplies simulator evidence for that recovery state only.

Logs: `build/logs/m4-core.log`, `m4-build.log`, `m4-watch-ui.log`, and
`m4-invalid-key-ui.log`. Watch regression result bundle:
`build/Watch/Logs/Test/Test-BulbAssistWatch-2026.10.09_16-13-49-+0530.xcresult`.
Focused invalid-key bundle:
`build/Watch/Logs/Test/Test-BulbAssistWatch-2026.10.09_16-18-03-+0530.xcresult`.
[Reachable measurement reset](screenshots/measurements-reset.png) was exported
from the passing native test and visually inspected.

One package run concurrent with simulator UI testing stalled and was interrupted.
The isolated measurement suite and subsequent full package run passed; no cause
is established for that stall. These results do not pass any physical milestone
exit. M4 remains open until the owner records the hardware observations above.
