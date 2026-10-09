# M1 Native Prototype Validation

Recorded 2026-10-08; completed 2026-10-09. Build 0.1.0 (1). M1 is complete:
both simulator builds, 14 core tests, and four functional Watch UI tests pass.
These results establish simulated behavior only. Dedicated VoiceOver work and
accessibility auditing are outside the owner's requested scope.

## Environment And Builds

- Xcode 26.4.1 (17E202), Swift 6.3.1, XcodeGen 2.42.0.
- Minimum iOS/watchOS 26.0; simulator runtimes iOS/watchOS 26.4.
- Dedicated simulators: Series 8 41mm, Series 8 45mm, and iPhone 17 Pro.
- `make build-watch`: passed with signing disabled.
- `make build-iphone`: passed, including the embedded Watch app.
- `make test`: 14 Swift Testing tests passed; the parameterized range test covers
  five inputs. Tests use zero simulated latency or continuation gates, without
  live networking or wall-clock sleeps.
- Watch scheme `test`: four Xcode UI tests passed with zero failures on the
  Series 8 45mm simulator. The final suite completed in 77.1 seconds.
  It exercises native taps and Digital Crown input against the simulated bulb.

Builds produce an expected AppIntents metadata warning because the prototype
does not depend on AppIntents. There are no Swift compiler errors or warnings.
Local logs are in ignored `build/logs/`; the Makefile reproduces the checks.

## Behavior Evidence

| Check | Evidence | Result |
| --- | --- | --- |
| Bounded input and raw mapping | 0/10/50/100/150 inputs; raw percentage × 10 | Pass |
| Opening does not write | Read raw 10, display 1%, no accepted command | Pass |
| Off-state selection | Core: choose 35%, idle sends nothing, Turn on applies raw 350. UI: 62% → 60% stays off, Turn on confirms 60% | Pass |
| No-edit power-on | Preserve reported raw 10 | Pass |
| Crown burst | 91 selections; one final idle write; duplicate idle adds no command | Pass |
| Unconfirmed readback | Accepted command with mismatched state never shows success | Pass |
| Offline/rejected/timeout | Distinct failures; controls blocked appropriately | Pass |
| Non-white mode | Power remains available; dimming blocked | Pass |
| Invalid numeric input | NaN/infinity ignored; finite extremes bounded safely | Pass |
| Background interruption | Draft discarded; obsolete power completion ignored | Pass |
| Unexpected raw range | Raw 0 and 1001 rejected | Pass |
| Native off/Crown journey | 45mm: Turn off, then simulated Crown input selects 63%; screen still says Bulb stays off | Pass |
| Native on-state dimming | 45mm Crown input: 62% → 64%, Setting… → On after idle | Pass |
| Native local draft | 45mm off: 62% → 61%, Next time and Bulb stays off remain visible | Pass |
| Crown after power actions | UI: dim after Turn on; Turn off, then select locally while still off | Pass |
| Crown after connection details | UI: open details, return, rotate Crown, confirm changed brightness | Pass |
| Compact layout | 41mm regular control screenshot reviewed; fixed crowded dial text | Pass |
| Larger text | 41mm `.xxxLarge` control screenshot reviewed; decorative arc/hint omitted | Pass |
| Recovery layout | Offline and timeout screenshots reviewed; text wraps and content scrolls | Pass for layout |
| Recovery scrolling | 41mm larger-text timeout scrolled to expose the full Check status action | Pass |
| Recovery action reachability | 45mm larger-text timeout: Crown scroll exposes hittable Check status button | Pass |
| Companion welcome | iPhone 17 Pro screenshot reviewed; clear simulated-prototype explanation | Pass for layout |

The Watch runtime rejects `simctl ui content_size` with “Runtime does not support
dynamic text.” `--large-text` overrides SwiftUI Dynamic Type to `.xxxLarge` for
layout inspection. It is not evidence of changing the system text-size setting.

## Screenshots

- [45mm on](screenshots/watch-45-on.png)
- [41mm off](screenshots/watch-41-off.png)
- [41mm larger text](screenshots/watch-41-large-text.png)
- [45mm offline](screenshots/watch-45-offline.png)
- [41mm larger-text timeout](screenshots/watch-41-timeout-large-text.png)
- [41mm recovery action after scrolling](screenshots/watch-41-recovery-scrolled.png)
- [45mm off-state local draft](screenshots/watch-45-off-draft.png)
- [UI: off-state local draft](screenshots/watch-45-ui-off-draft.png)
- [UI: Turn on applies the draft](screenshots/watch-45-draft-applied.png)
- [UI: Crown after Turn on](screenshots/watch-45-crown-after-power-on.png)
- [UI: local draft after Turn off](screenshots/watch-45-crown-after-power-off.png)
- [UI: connection details](screenshots/watch-45-connection-details.png)
- [UI: Crown after returning](screenshots/watch-45-crown-after-details.png)
- [UI: confirmed on-state dimming](screenshots/watch-45-ui-on-confirmed.png)
- [UI: larger-text recovery action](screenshots/watch-45-large-text-recovery.png)
- [iPhone welcome](screenshots/iphone-welcome.png)

## Reproduce

Open `BulbAssist.xcodeproj` in Xcode and choose the `BulbAssistWatch` scheme with
a Series 8 simulator. `BulbAssist` runs the iPhone welcome and simulated slider
preview. Xcode scheme arguments support:

```text
--off
--below-range
--color-mode
--scenario=normal|slow|offline|rejected|unconfirmed|timedOut
--large-text                 (Watch only)
```

Use one value for `--scenario`; the vertical bars above describe alternatives.
The Debug connection-details picker changes the simulated scenario without
relaunching. Watch and phone simulations are independent.

Run the shared-core tests with `make test`, both builds with `make build`, and
the functional Watch tests with `make test-watch-ui`. The UI command defaults
to the locally created `Bulb Assist Series 8 45mm` simulator. For another
installed simulator, provide its UUID:

```sh
make test-watch-ui WATCH_DESTINATION='platform=watchOS Simulator,id=YOUR_UUID'
```

The final recorded run used:

```sh
xcodebuild -project BulbAssist.xcodeproj -scheme BulbAssistWatch \
  -destination 'platform=watchOS Simulator,id=40C9461D-06F7-4FEA-9096-BF0CB4E6A953' \
  -derivedDataPath build/Watch \
  -resultBundlePath build/results/m1-watch-ui-complete.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

Use a fresh result-bundle path when repeating that command. The result bundle
and full logs remain in ignored `build/`; selected screenshot attachments are
saved above. The suite source is
[WatchRemoteUITests.swift](../../Tests/WatchUITests/WatchRemoteUITests.swift).

Direct tap delivery through the computer-use tool was unreliable. The owner
authorized Xcode UI tests on 2026-10-09. The first run found a test-query ambiguity
in SwiftUI's nested toolbar wrappers; selecting the first matching button fixed
the query. The final suite includes Crown checks after both power actions and
passes all four tests. No application behavior change was needed to pass them.

## Scope And Later Milestones

Per the owner's 2026-10-09 direction, VoiceOver functionality/testing and the
accessibility audit are outside the current scope. The custom VoiceOver brightness
adjustment action was removed; native control metadata and UI-test identifiers
remain. Add accessibility work only if a strict Apple requirement applicable to
this personal prototype is identified. There is no remaining VoiceOver validation
gate for this milestone or the physical-device milestone.

M1 brightness delivery is final-on-idle. M2 adds paced intermediate values,
power-off ordering, shared request budgeting, bounded confirmation/recovery, and
foreground cancellation. Basic session invalidation in M1 is not proof of the
complete M2 scheduling contract.

No API key, Tuya adapter, Keychain provisioning, or WatchConnectivity is used by
these apps. M3 adds live integration. No physical Series 8 latency, haptics,
credential transfer, or lamp response was measured. The owner's watchOS 26.3
must be checked separately from the installed 26.4 simulator runtime. Exact
iPhone OS and signing team remain required before physical installation.
