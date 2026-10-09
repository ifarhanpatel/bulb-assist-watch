# Parallel Implementation and Validation Plan

Created 2026-10-09. Status: all three streams implemented and integrated;
combined native regression passed; the owner confirmed the guided physical M3
exit checks. M1–M3 are complete; merged M4 hardware and daily-use readiness remains open (former M5 included).
See [integration evidence](../validation/parallel/native-integration.md). Baseline: M1 commit `2062817`, with both simulator builds, 14 core tests,
and four Watch UI tests passing.

Run three implementation streams after a short shared-contract step: M2 command
behavior, the M3 Tuya adapter, and M3 companion setup and provisioning. Each
stream owns its implementation and tests. One integration owner manages shared
contracts, project configuration, merges, and final validation. M2 remains the
critical path: live control starts only after its scheduling checks pass.

This changes implementation order, while preserving the milestone exits in
[Delivery Tasks](tasks.md). M3 work can be built and tested with fixtures before
M2 finishes; M3 is complete only after integration and physical-device checks.
Use the [Technical Spec](technical-spec.md), [Product Spec](product-spec.md), and
[Pen handoff](../../design/review.txt) as the behavior and visual references.
Dedicated VoiceOver work and accessibility audits remain outside scope.

## Shared Contracts Before Parallel Work

The integration owner completes this step first and gives all three streams
the same resulting commit. Preserve the simulated prototype and passing M1
checks while adding the interfaces needed by the three implementations.

| Contract | Decision to establish before starting |
| --- | --- |
| Bulb control | Retain the `BulbControlling` seam: `readState()` returns reported state; `apply(_:)` establishes API acceptance only. The adapter performs one request per operation and does not retry commands or schedule confirmation. |
| State and errors | Add observation timing and typed authentication, rate-limit, missing-device, unsupported-schema, transport, and uncertain-write outcomes. Define which failures establish rejection and which require reconciliation. Agree on Retry-After representation and cancellation behavior. |
| Remote interface | Preserve the view's selection, power, refresh, activation, and deactivation entry points where practical. Specify pending, stale, unconfirmed, cooldown, and setup-required states so the Watch screen can render them consistently. |
| Clock and request policy | Inject a clock and policy into the coordinator. Simulated spacing starts at 500 ms; first live spacing is at least 1 second across reads and writes. Request timeout is 5 seconds; final confirmation allows at most two reads within a 5-second window. |
| Discovery | Define a small discovery interface for listing devices and validating a selected device's capabilities. Setup uses this interface; the Tuya stream supplies its real adapter and a fixture implementation supplies tests. |
| Configuration lifecycle | Define selected-device metadata, monotonically increasing configuration revisions, provision/replace/remove messages, and acknowledgements. Credentials travel only in active messaging and remain in device-local Keychain. A persistence acknowledgement and a successful direct Watch read are separate results. |
| Credentials | Inject credential storage and active-message transport into setup logic. Define store/load/delete behavior, idempotent revision handling, and cancellation when configuration is replaced or removed. |
| App construction | Replace the current requirement that every remote receives a `SimulatedBulbController`. Keep simulation controls in the prototype path; construct a configured remote with an injected `BulbControlling` adapter. |

Keep pure setup and control contracts in BulbCore. Keep Keychain and
WatchConnectivity implementations in app platform code with injectable test
adapters. Do not require WatchConnectivity to compile the package's macOS tests.
Agree on exact type names and signatures during this step; the table defines
behavior, not interfaces already present in M1.

The integration owner also sets up any new app test targets and regenerates the
Xcode project once. Run the existing core tests, both builds, and Watch UI suite
before releasing the shared commit. A stream that needs a contract change sends
the change to the integration owner; do not independently change shared types.

## File Ownership and Isolation

Use one Git worktree and branch per stream, all based on the shared-contract
commit. Use a separate integration checkout. The branch names below are proposed
for the implementation run, not branches created by this plan.

| Owner | Proposed branch | Files owned |
| --- | --- | --- |
| Stream A, command behavior | `m2-command-behavior` | BulbRemote and new scheduling implementation, SimulatedBulbController, control test doubles, existing core behavior tests and new coordinator tests |
| Stream B, Tuya adapter | `m3-tuya-adapter` | New `Packages/BulbCore/Sources/BulbCore/Tuya/` implementation, Tuya test files, and synthetic/redacted HTTP fixtures |
| Stream C, companion setup | `m3-companion-setup` | New pure setup implementation under `BulbCore/Setup/`, `Apps/iPhone/` setup views excluding `BulbAssistApp.swift`, new `Apps/Shared/Provisioning/` platform adapters, setup and platform tests |
| Integration owner | `parallel-integration` | Shared contract files, Package.swift, project.yml and generated project, Makefile, app construction, shared Watch remote/details views, Watch UI tests, specs and validation records |

Directory names are proposed additions. Each stream may add files within its
owned area; ownership of shared files remains with the integration owner.
Stream C supplies the setup navigation entry to the integration owner, who wires
it into the application. Stream A supplies its status model, which the integration
owner connects to the existing Watch views. This avoids competing edits to
`Apps/Shared/RemoteView.swift`, `ConnectionView.swift`, and `Prototype.swift`.

Give each checkout its own Swift scratch directory, Xcode DerivedData directory,
and result bundles. Do not run tests that install or launch the same app on the
same simulator concurrently. Package tests and fixture tests can run in parallel;
serialize simulator UI sessions on this Mac unless each has a distinct simulator
and a runner that supports concurrent use. Physical lamp checks are sequential.

## Stream A Command Behavior

Build scheduling and recovery together, with tests alongside each behavior:

1. Track requested, accepted, and reported revisions independently; maintain
   immediate local feedback and prevent obsolete responses from completing a
   newer selection.
2. Serialize reads and writes, retain only the latest pending brightness, pace
   intermediate writes, deliver the final idle value, and deduplicate it.
3. Allow power-off to discard queued dimming and follow any in-flight request.
   Block repeated power actions, ignore Crown input during power transitions,
   and preserve the agreed local draft behavior while off.
4. Bound confirmation, stop on uncertain writes and rate limits, cancel/discard
   background work, and read fresh state on foreground entry without replay.

Validate through the coordinator interface with a fake clock and a gated adapter
that records starts, completions, cancellation, and maximum concurrent requests.
Include rapid reversals/endpoints, slow responses, older readback after a new
gesture, repeated idle, power-off during dimming, below-range reported brightness,
non-white mode, write timeout, failed confirmation, Retry-After, and interruption.

Pass when tests prove: at most one request in flight; at most one pending
brightness intent; every request respects the configured spacing; no obsolete
rollback or replay; correct power ordering; and final reported confirmation under
normal simulated connectivity. Two confirmation reads and the overall window
must be enforced. Cancellation cannot undo an accepted server write; uncertain
outcomes require reconciliation, and cancellation must not permit overlapping
requests. The UI must remain responsive while work is waiting.

## Stream B Tuya Adapter

Implement device discovery, detail/model parsing, and explicit property commands
using the proven helpers and agreed contracts. Inject HTTP transport and
credentials; keep scheduling, command retry, and confirmation out of this adapter.
Validate model capabilities before enabling dimming. Read reported raw values
without clamping; write only explicit power/brightness patches, preserving mode
and color temperature.

Use mocked HTTP responses and synthetic/redacted fixtures for:

- Region routing, bearer authentication, device selection, escaped device paths,
  and JSON-string model/property fields.
- Power-on with and without a draft, power-off, brightness mapping, and omission
  of unrelated properties.
- HTTP and API-envelope failures, invalid keys, rate limits and Retry-After,
  offline/missing devices, malformed data, unsupported schema, and rejected
  redirects.
- Transport timeout and cancellation, correct uncertain-write classification,
  and errors/logs that omit credentials, device identifiers, and raw response bodies.

Pass when tests assert exact requests and resulting domain outcomes through the
adapter's interfaces. Normal automated tests use no API key and cannot change
the physical lamp. Supply discovery and control adapters plus integration notes
for Stream C and the integration owner.

## Stream C Companion Setup and Provisioning

Build the Pen setup flow against injected discovery, credential storage, and
active-message transport. Implement secure key entry, device selection, model
validation, provisioning status, replacement, removal, and actionable errors.
Keep pure setup logic testable in BulbCore. Add the real Keychain and
WatchConnectivity adapters in app code without embedding credentials in source,
build settings, logs, UserDefaults, or persistent application-context payloads.

Validate setup with scripted discovery, an in-memory credential store, and a
gated messaging adapter. Cover invalid input, discovery failure, unsupported
devices, unreachable Watch, interrupted provisioning, persistence failure,
duplicate messages, stale acknowledgements, relaunch, replacement, and removal.
An acknowledgement counts only after Watch persistence or deletion succeeds.
Only a successful direct Watch read establishes connection success. Show pending
removal while the Watch has not acknowledged deletion; prevent obsolete
acknowledgements from restoring removed or replaced configuration.

Run native platform tests for Keychain store/load/replace/delete and simulate
the companion screens' success/error/pending states. Pass when the pure setup
tests and applicable platform tests pass, both targets compile, and credentials
are absent from logs and fixtures. Mocked messaging proves lifecycle logic;
real paired-device delivery remains an integration gate.

## Validation While Streams Run

Each stream runs its own tests in its checkout after every meaningful behavior
change. Keep the complete package suite passing before handing off a branch.
These are existing commands usable in each checkout:

```sh
make test
make build-watch
make build-iphone
make test-watch-ui WATCH_DESTINATION='platform=watchOS Simulator,id=YOUR_UUID'
```

Run package tests for all three streams concurrently using separate checkouts.
Build the app targets when a stream changes platform code or supplies its final
handoff. The integration owner supplies the new platform-test commands during
the shared-contract step and reserves simulator sessions for native tests.
Do not label a stream validated solely because its types compile.

Each handoff contains a commit, a summary of implemented behavior, exact test
commands and outcomes, assumptions or remaining failures, and requested shared
file changes. Save evidence under `docs/validation/parallel/` during implementation.
Do not include credentials in handoff reports or artifacts.

## Integration and Milestone Gates

The integration owner merges validated work in this order and checks the resulting
commit at each gate. If a gate fails, fix it before enabling the next path.

| Gate | Integration and required evidence |
| --- | --- |
| Shared contracts | All streams start from the same compiling contracts; M1 regression checks pass. |
| M2 simulated behavior | Merge A, connect Watch pending/recovery states, run the complete core suite and both builds. Run the Watch UI regression suite and add UI checks for power-off during dimming, cooldown/recovery, and foreground reconciliation. Inspect compact/larger-text states. Record M2 exit evidence. |
| Tuya integration | Merge B and run the coordinator against mocked Tuya transport. Prove shared read/write spacing, final confirmation, timeout/rate-limit behavior, and no retries or overlapping requests hidden inside the adapter. Verify discovery results satisfy the setup contract. |
| Setup integration | Merge C, wire application construction and configured Watch launch, and run all pure/platform tests. Validate provisioning, replacement, and removal with the fixture discovery path and simulated messaging. Re-run Watch UI checks when launch/state construction changes. |
| Native regression | Build both targets, run the complete core/platform suites and affected UI journeys, and save screenshots/result bundles. Verify the prototype path still runs without credentials. |
| M3 physical control | Confirm exact device OS versions and signing team; install on the paired iPhone 17 Pro and Series 8. Provision through active messaging, relaunch, read directly from Watch, then verify power on, one brightness change, and power off. Check replacement/removal acknowledgements on the pair. Record API acceptance, cloud readback, and owner-observed lamp outcomes separately. |

Live physical tests remain manual and outside routine automated tests. The owner
merged M4/M5 on 2026-10-09: ordinary-gesture measurements, 10 power actions,
recovery, three-day use observations, provider access and maintenance documentation
now share one M4 milestone. Endpoint/reversal checks are deferred by owner decision.
Passing simulated integration does not establish Crown feel, physical latency, or
daily-use readiness.
Provider quota/access-term clarification can proceed alongside implementation;
faster live pacing still depends on the applicable quota permitting it.

## Start Sequence and Completion

1. Prepare and validate the shared-contract commit.
2. Start A, B, and C in isolated checkouts with the ownership and test expectations
   above. Each owner implements and validates its stream independently.
3. Integrate A and complete M2 while B and C continue their fixture work.
4. Integrate B and C as their handoffs pass, complete native regression, then
   run the physical M3 gate with the owner.
5. Update milestone tasks and validation records with passing evidence. Commit
   and push integrated results according to the active delivery instruction.

Parallel implementation is complete when all three stream handoffs pass and the
combined app passes native regression. Mark M2 complete at its simulated gate;
mark M3 complete only after its physical gate. If device installation is waiting
on OS/signing information, retain that explicit outstanding check while keeping
the integrated simulator build runnable.
