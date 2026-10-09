# Parallel delivery validation — 2026-10-09

Shared gate `0ffaaea` passed before three agents began in isolated Git worktrees.
Integrated command behavior first, then Tuya after its coordinator gate, then
companion setup. Branch: `codex/parallel-integration`. VoiceOver work is excluded.

## Stream evidence

| Stream | Handoff | Passing owner validation |
| --- | --- | --- |
| A command behavior | `765697b` | 35 package tests; scheduling/recovery gate |
| B Tuya adapter | `8749978` | 38 package tests, including 22 HTTP/model tests |
| C setup/provisioning | `9d39820`, follow-up `b99408e` | 40 package tests, including 24 lifecycle tests; both builds; seven new native tests compiled |

Reports: [A](stream-a.md), [B](stream-b.md), [C](stream-c.md),
[shared contracts](shared-contracts.md), [M2/Tuya gate](m2-integration.md).
Each stream kept its own Swift scratch and Xcode build directories. Simulator
sessions were serialized. No live API credentials or physical lamp commands were
used in automated tests. All HTTP fixtures and setup credentials are synthetic.

## Integrated automated gates

- Full BulbCore suite: **85 tests in six suites passed**, zero failures.
  Log: `build/logs/final-core.log`. Includes four real-adapter/coordinator tests
  proving shared live spacing, one request at a time, final confirmation,
  rate-limit stop/recovery, uncertain-write timeout without retries/replay,
  and no hidden adapter readback.
- Both app simulator builds passed, with strict Swift 6 concurrency.
  Logs: `build/logs/final-watch.log`, `build/logs/final-iphone.log`, and
  `build/logs/final-iphone-adhoc.log`. Only the existing AppIntents metadata
  warning appears; no Swift compiler errors/warnings.
- **Eight native platform tests passed**: real Keychain store/load/replace/delete,
  device-only protection, durable tombstones, stale/conflicting revision rejection,
  native receiver persistence/deletion acknowledgement ordering, wire codec,
  and cancellation/duplicate/late reply handling.
  Bundle: `build/results/native-keychain-adhoc.xcresult`.
- **Three companion UI tests passed**: fixture provisioning and direct read,
  key replacement, acknowledged removal, invalid key recovery, and an unreachable
  Watch remaining pending. Bundle: `build/results/final-iphone-ui-fixed.xcresult`.
- **Eight Watch UI tests passed**, zero failures, 135.065 s. Includes all four
  M1 journeys, power-off during slow dimming, cooldown/explicit recovery,
  foreground reconciliation without off-draft replay, and configured fixture
  launch with the simulation picker absent.
  Bundle: `build/results/final-watch-ui.xcresult`.
  The final larger-text check also requires the recovery button's entire frame
  to fit on screen after Crown scrolling. That stricter check and cooldown
  recovery both passed again, zero failures, 33.988 s.
  Bundle: `build/results/watch-final-scroll-checks.xcresult`.

All three stream handoffs and the combined native regression gate pass. M2 is
complete. M3 implementation is integrated; its guided physical functional exit
is now owner-confirmed, with the evidence limits recorded below.

The first platform run used the M1 unsigned simulator command and failed Security
operations. An ad-hoc-signed simulator host supplies the required application
identity. Makefile simulator builds/tests now use `CODE_SIGNING_ALLOWED=YES
CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO`; this needs no device provisioning
profile. [Apple's entitlement diagnosis](https://developer.apple.com/documentation/security/errsecmissingentitlement)
explains the identity requirement. The signed native run passed all eight tests.

Native execution also caught a real settings-navigation issue: a cached destination
kept showing the connected page after replacement began. The setup owner supplied
an observable destination and stable presentation, with restore disabled on the
settings flow. The complete replacement/removal native journey then passed.
The Debug Watch scenario picker now uses an explicit navigation list after its
initial wheel query failed; the recovery journey passes with native interaction.

## Construction and lifecycle

Unconfigured Watch launch shows iPhone setup instructions. Configured launch
loads device-local Keychain, validates its model, and constructs a remote with
an injected Tuya adapter and live policy. Model validation is separated from the
first detail read by at least one second; replacing configuration waits for the
old coordinator's actual drain before creating another adapter.

Provisioning persistence and direct verification remain separate results.
Watch verification goes through the same coordinator as foreground control,
preventing an extra read path from bypassing serialization/spacing. Foreground
state guards prevent setup verification from enabling background control.
Phone active-message state changes retry only pending provisioning/removal.
Prototype and fixture paths inject simulated control and need no credentials.

Code inspection found no credential/device/body logging, UserDefaults credential
storage, application-context writes, or transferUserInfo provisioning path.
Keychain tests use isolated disposable services; no test touches the app's account.

## Visual evidence

Reviewed compact controls and larger-text cooldown on Series 8 41mm. The recovery
content scrolls when its action is below the fold; native larger-text tests verify
that the entire recovery action is visible and hittable. The final screenshot
captures that fully exposed action. Companion screenshots show connected,
replacement, removal, invalid-key and pending states with native adaptive scrolling.

- [Configured fixture launch](screenshots/watch-configured-fixture.png)
- [Reachable larger-text recovery](screenshots/watch-large-recovery-action.png)
- [Power-off during dimming](screenshots/watch-power-off-dimming.png)
- [Compact Watch control](screenshots/m2-41mm-control.png)
- [Compact larger-text cooldown](screenshots/m2-41mm-large-cooldown.png)
- [Fixture connected](screenshots/iphone-fixture-connected.png)
- [Fixture replacement](screenshots/iphone-fixture-replaced.png)
- [Fixture removal](screenshots/iphone-fixture-removed.png)
- [Invalid key](screenshots/iphone-key-error.png)
- [Unreachable Watch](screenshots/iphone-fixture-pending.png)

## Physical M3 — owner-confirmed functional exit

The connected iPhone 17 Pro reports **iOS 27.0** in both native device metadata
and Xcode's device window. The owner reports **watchOS 26.6 on Series 8**.
These replace the earlier supplied 26.3 versions for this physical run.
The Mac reports macOS 26.6.1. Both app targets now show the owner's private team,
automatic signing, managed profiles, and no signing error.

The initial device build failed because a selected local iPhone provisioning
profile was missing (`build/logs/device-signing-build.log`), and Xcode 26.4.1
initially exposed no physical Watch. Two repeated destination checks reproduced
that exact discovery failure. The owner confirmed shared Wi-Fi and enabled
Wi-Fi/Bluetooth. Device metadata confirmed the iPhone was paired over USB with
Developer Mode enabled; Xcode's installed-app list confirmed the companion app.

The owner then reported the Watch connected. The active project was now open in
**Xcode 27.0**. Its selected scheme/destination were BulbAssistWatch and the owner's
physical Watch. The repeated destination check now passed, with one real watchOS
destination (`build/logs/watch-connected-destinations.log`). Both shared schemes
had no enabled simulation launch arguments. The tool/version change and successful
discovery were observed together; no isolated causal fix is claimed.

Following the guided install, provisioning, and first-control checklist, the owner
confirmed that **both setup and actual lamp control work**. This is owner-reported
physical evidence. No API key was supplied to the agent. Per-command API acceptance
and cloud readback were not captured independently, and no physical-response
timings or request counts were measured during this first run.

The owner subsequently confirmed the guided close/reopen and Watch Refresh check
works: saved configuration survives relaunch, and the fresh reported state matches
the lamp without changing it. This is owner-reported persistence/read evidence.

The owner then confirmed the guided physical key replacement, acknowledged
removal and subsequent setup checks work. The checklist required Watch control
after replacement, a confirmed removal screen on iPhone, setup instructions on
Watch, and reprovisioning for normal use. No provider key revocation was requested.

### Separate control evidence

The guided control check was power-on, one Crown brightness change (approximately
50% requested), then power-off, waiting for reported state and observing the lamp
after each action. The owner confirmed both setup and actual lamp control work.

| Action | API acceptance evidence | Cloud/reported-state evidence | Physical evidence |
| --- | --- | --- | --- |
| Power on | Inferred from the successful app flow; no independent HTTP capture | Agreement required by guided check and covered by owner confirmation; exact snapshot not saved | Owner-confirmed working control |
| One brightness change | Inferred from the successful app flow; no independent HTTP capture | Agreement required by guided check and covered by owner confirmation; exact value/snapshot not saved | Owner-confirmed working control |
| Power off | Inferred from the successful app flow; no independent HTTP capture | Agreement required by guided check and covered by owner confirmation; exact snapshot not saved | Owner-confirmed working control |

M3's **functional physical exit passes on owner-reported evidence**. This record
does not claim independent HTTP traces, measured physical-response latency,
request counts or smooth intermediate dimming. Those measurements, hardware recovery, sustained-use/provider-access
and maintenance checks belong to the merged M4 (former M5 included by owner
direction on 2026-10-09). Ordinary gestures and 10 power actions remain open;
endpoint/reversal trials are deferred by owner decision. VoiceOver remains excluded.
