# Shared contracts — 2026-10-09

All streams start from the shared-contract commit recorded in the integration log.
VoiceOver work remains excluded. Pure contracts live in BulbCore/Contracts.

- `BulbControlling`: one operation per adapter call; `apply` establishes acceptance only.
  Cancellation must drain the adapter operation before another request begins. A
  cancelled or timed-out issued write may have applied; reconcile without replay.
- `BulbSnapshot.observedAt`: wall-clock observation time. Reported brightness is
  preserved without UI-range clamping. `BulbFailure` adds authentication, rate limit
  (optional Retry-After seconds), missing device, schema, transport, uncertain write.
  `requiresReconciliation` identifies potentially applied writes; cancellation of
  an issued write is also uncertain.
- `BulbClock`: monotonic seconds and cancellable Duration sleep. `RequestPolicy`
  supplies 500 ms simulated / 1 s live spacing, 5 s timeout, at most two confirmation
  reads in 5 s, and a 5 s fallback cooldown. Stream A owns RemoteStatus and must
  report its exact cases to integration before Watch wiring.
- `BulbDiscovering`: list selected-device metadata, then validate power/brightness
  capabilities. Discovery instance is bound to credentials by construction.
- `CredentialStoring`: load configuration, latest revision, store, delete with
  tombstone revision. Revisions survive deletion and relaunch. Store implementation
  must enforce stale/duplicate handling. The Keychain bundle may include metadata;
  credentials never enter UserDefaults or persistent messaging context.
- `ProvisioningMessage`: provision/replace a configuration, remove a revision,
  verify a revision. Replies distinguish persisted, removed, connected(snapshot),
  and typed failure. Only a direct Watch read may produce connected. Reply revisions
  must match the active operation. Receiver invalidates old control before replace
  or remove and acknowledges persistence only after durable success.
- Platform implementations stay in Apps/Shared/Provisioning. Package tests need
  neither Security nor WatchConnectivity. `make test-platform` is the serialized
  iPhone platform test command; `make test-watch-ui` is the Watch UI command.
- Shared RemoteView/ConnectionView now accept an optional simulation adapter so
  configured construction does not require simulation. Only the prototype exposes
  its scenario picker. Integration owns app construction and all shared views.

Ownership and handoff requirements are in the parallel delivery plan. Each stream
uses its own worktree-local build directory and records validation without secrets.

Shared gate passed: `make test` (16 tests), `make build-watch`,
`make build-iphone`, iPhone `build-for-testing`, and the existing Watch UI suite
(four tests, zero failures, 76.864 s). Watch result bundle:
`build/results/shared-watch-ui.xcresult`; logs: `build/logs/shared-*.log`.
No live credentials or physical lamp operations were used.
