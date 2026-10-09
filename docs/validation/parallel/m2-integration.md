# M2 simulated integration — 2026-10-09

Stream A `765697b` integrated after shared-contract gate `0ffaaea`.

- `make test`: 35 tests, zero failures.
- `make build-watch`, `make build-iphone`: passed.
- Watch native suite: existing four journeys plus power-off during slow dimming,
  cooldown/explicit recovery, and foreground refresh without off-draft replay.
  Six journeys passed in `build/results/m2-watch-ui.xcresult`. The new cooldown
  journey initially queried a wheel as a Picker; native hierarchy inspection led
  to an explicit Debug navigation-list picker and stable identifier. Its final
  run passed in `build/results/m2-cooldown-navigation.xcresult` (21.576 s).
- Pending, stale, unconfirmed, cooldown, setup-required and typed failure states
  are wired to shared Watch views. Live views accept no simulation adapter;
  only prototype views expose the Debug scenario picker.
- The complete Watch suite was repeated after configured-launch integration.
  Compact/larger-text inspection is recorded in final native regression evidence.

Core gated/fake-clock evidence proves one in-flight request, latest pending
brightness, read/write spacing, no obsolete rollback or replay, power-off order,
max two confirmation reads in five seconds, and cancellation drain ownership.
See stream-a.md for the complete behavior matrix. M2 simulated behavior is passed;
no physical latency, Crown feel or live lamp outcome is established here.
VoiceOver work is excluded.

Tuya integration gate: `make test` passed 61 tests in five suites after merging
Stream B. Four additional fake-clock tests exercise the coordinator through the
real Tuya controller and synthetic HTTP transport: final selection, shared live
spacing/one request at a time, rate-limit stop and explicit recovery, uncertain
write timeout without replay, and exactly two visible confirmation requests.
No API key or physical lamp was used. Log: `build/logs/tuya-integration-core.log`.

Final native regression passed all eight Watch tests in one run (135.065 s),
including configured launch. Compact control and larger-text cooldown screenshots
were visually inspected on Series 8 41mm; larger-text recovery reachability passes
natively. The stricter whole-button visibility check and cooldown recovery also
passed in `build/results/watch-final-scroll-checks.xcresult` (two tests, 33.988 s).
See [complete integration evidence](native-integration.md). M2 is complete.
