# Product Spec

Public source release note (2026-10-09): this spec records the original single-bulb
product scope. Publication does not expand validated hardware support or complete
M4; see [compatibility](../compatibility.md) and [release preparation](open-source-readiness.md).

## Document Status

- Status: M1–M3 complete with owner-confirmed physical checks; merged M4 hardware and daily-use readiness in progress
- Last updated: 2026-10-09
- Owner: Farhan Patel

## Problem

The Wipro Next Smart Home app does not provide an Apple Watch experience for the
Wipro NS9001 bulb. The user wants to adjust the bulb's brightness from their
wrist using the Apple Watch Digital Crown instead of reaching for a phone and
operating the vendor app.

## Target Users

- Primary user: the owner of this personal project and their Wipro NS9001 bulb
- Secondary user: none in v1
- Target hardware: Apple Watch Series 8 (owner-reported watchOS 26.6) and iPhone 17 Pro
  (device-reported iOS 27.0); reconfirm versions during M4

## User Problems

- The Wipro NS9001 does not support HomeKit and therefore cannot be controlled
  directly through the Apple Watch Home app.
- Adjusting brightness through the phone app adds avoidable interaction steps.
- Continuous brightness adjustment needs clear feedback and must not overwhelm
  the bulb or integration service with commands.

## Goals

- Provide a focused Apple Watch remote for one Wipro NS9001 bulb.
- Let the user adjust brightness with the Digital Crown.
- Support reliable power control and clear success, offline, and timeout states.
- Keep bulb communication behind an adapter so interaction and failure behavior
  can be tested without a live bulb or credentials.
- After setup, support routine control with the phone unreachable when the Watch
  has an internet connection.

## Non-Goals

- Supporting bulbs other than the Wipro NS9001
- HomeKit accessory emulation
- Multi-user accounts, device sharing, or App Store distribution
- Schedules, automations, rooms, groups, or multiple bulbs
- Advanced scenes and color selection
- Background dimming, complications, Siri integration, and a hosted backend
- Dedicated VoiceOver functionality or testing. Additional accessibility work
  is in scope only for a verified Apple requirement applicable to this app,
  per the owner's 2026-10-09 direction.

## Core User Journeys

### Journey 1: Initial setup

1. User installs the iPhone companion and Apple Watch app.
2. User enters their existing Tuya End User API key in the iPhone companion.
3. User selects their NS9001 bulb; the app checks its supported controls.
4. With both apps open, the companion provisions the Watch securely.
5. The Watch reads the bulb state directly and confirms that setup is complete.

### Journey 2: Repeat usage

1. User opens Bulb Assist on Apple Watch.
2. User rotates the Digital Crown.
3. The interface immediately reflects the selected brightness.
4. The app sends brightness updates at a controlled rate and confirms the final
   bulb state.

When the bulb is off, Crown rotation changes only the local selection. No
brightness command is sent until the user taps power to turn it on. This behavior
was chosen by the owner on 2026-10-08.

### Journey 3: Power control

1. User opens Bulb Assist on Apple Watch.
2. User taps the power control.
3. The app shows the resulting on/off state or a clear failure state.
4. Turning on applies a locally selected brightness, if present; otherwise it
   preserves the bulb's reported brightness. Turning off discards pending dimming
   commands so a delayed update cannot intentionally turn the bulb back on.

## Functional Requirements

- FR1: The Watch app must control power for one configured Wipro NS9001 bulb.
- FR2: The Watch app must provide the planned 10–100% brightness UI range using
  Digital Crown rotation, with the adapter mapping it to the device's reported
  raw brightness schema. This UI range does not assert a physical bulb minimum.
- FR3: The interface must update locally while the crown rotates, without waiting
  for each network response.
- FR4: Brightness commands must be throttled or debounced to avoid flooding the
  bulb-control service, while ensuring the final selected value is sent.
- FR5: The system must show connecting, connected, offline, timeout, and failed
  command states.
- FR6: Bulb communication must be isolated behind a control adapter.
- FR7: The prototype must provide a simulated adapter before real-device
  integration is available.
- FR8: Crown rotation while off must only select brightness locally. Power-on
  applies that selection; opening the app must never change the bulb.
- FR9: The companion must support API-key entry/replacement, single-bulb
  selection, and acknowledged provisioning to the Watch. Credentials are stored
  in each device's Keychain.
- FR10: After setup, foreground Watch control must work without a reachable phone
  when the Watch has internet access.
- FR11: On reopening or returning from an interruption, the app must read current
  state before accepting commands and must not replay old dimming requests.
- FR12: v1 brightness control operates in white-light mode. If another mode is
  reported, show a prompt to select white mode in Smart Life and disable dimming;
  retain power control. Do not change mode or color temperature automatically.

## Quality Requirements

- QR1: Power and brightness must be usable without navigating between screens.
- QR2: Crown interaction must feel immediate even when bulb communication is slow.
- QR3: Failures must be observable and debuggable without exposing credentials.
- QR4: Core interaction and command-rate behavior must be testable without a
  physical bulb.
- QR5: Secrets or service credentials must not be stored directly in Watch UI code.

## Interaction And Feedback

- One Watch screen: bulb name, large brightness value, power button, and concise
  status. Crown focus returns after a power-button interaction.
- Local selection is immediate. Pending work is visible; an API acceptance alone
  is not presented as confirmed bulb state.
- Matching cloud readback means the service reports the requested state. Physical
  light response is verified separately in device acceptance testing.
- Display an externally reported brightness below the 10% control range honestly;
  clamp only an explicit new Crown selection. Do not send a correcting write.
- While off, label an edited brightness as the value for the next power-on. This
  draft lasts only for the current active session and is discarded on reopening.
- Keep text readable, control labels clear, and status cues explicit. Use native
  controls without adding a dedicated accessibility workstream.

### Accessibility Scope

This app is a personal prototype installed through Xcode, with App Store
distribution outside v1. No strict Apple requirement for dedicated VoiceOver
functionality was identified for that scope in the
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
checked 2026-10-09. Apple's
[accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility)
is design guidance; it does not by itself add a mandatory project milestone.
Any future accessibility requirement must identify the applicable Apple rule
before adding implementation or testing tasks.

## Success Metrics

- The user can change brightness from their wrist without opening the Wipro app.
- The displayed brightness responds immediately to Digital Crown rotation.
- The final requested brightness reaches the bulb during normal connectivity.
- A full brightness adjustment does not produce an unbounded command stream.
- Offline and timeout conditions are distinguishable from a successful command.

## Feasibility Evidence

The owner's NS9001 now pairs with Smart Life and works through phone/cloud
control, but Smart Life lists it as unsupported for direct Watch control.
An owner-run Tuya End User API test passed authentication, device discovery,
four physical power/brightness commands, matching state readback, and restoration.
The API's raw brightness range is 10–1000. The owner has since confirmed native Watch setup, direct control, relaunch
persistence and key lifecycle checks. Merged M4 covers latency, recovery and daily-use readiness;
these functional checks do not establish smooth intermediate dimming. See
[the physical evidence record](../validation/parallel/native-integration.md).
See the [feasibility assessment](../research/project-feasibility.md).

## Open Questions

- What quotas, key lifetime, mobile-use terms, and ongoing costs apply to Tuya
  End User API access?
- What latency and command frequency feel acceptable on the physical bulb?
- What is the paired iPhone's exact iOS version, and which signing team will be
  used for installation? These do not block the simulated implementation.

The implementation plan uses direct Watch HTTPS control and iPhone setup. See
the [technical spec](technical-spec.md) and [delivery tasks](tasks.md) for the
remaining device validation and daily-use gates.

## Acceptance Criteria For Spec Completion

- [x] The primary user is named.
- [x] The primary workflow is concrete.
- [x] v1 scope and non-goals are explicit.
- [x] Success metrics are defined.
