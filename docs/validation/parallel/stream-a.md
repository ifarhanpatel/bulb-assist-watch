# Stream A command behavior — 2026-10-09

Status: implementation and full package gate passed. Base: shared contracts
`0ffaaea`. Branch: `codex/m2-command-behavior`; isolated checkout:
`/private/tmp/bulb-assist-stream-a`. Dedicated VoiceOver work remains excluded.

## Implemented behavior

`BulbRemote` accepts `controller`, `clock`, and `policy`, with the original default
construction preserved. Crown input immediately updates the local selection.
One worker serializes every read and write; only the newest unsent brightness is
retained. Request starts share the policy spacing across reads and writes, and
idle never bypasses pacing. Intermediate values are sent while on. Final values
already issued or accepted are deduplicated, then confirmed with at most two
reads and a hard five-second overall window (also bounded by a shorter policy
window). Waiting for spacing counts against that window.

Requested, API-accepted, and matching reported revisions are independent public
properties. Old reads cannot clear or roll back a newer selection, and obsolete
read timeouts cannot discard the newer queue. Selecting the existing reported
brightness needs no command and does not invent API acceptance.

Power-off discards queued dimming and follows the current adapter operation.
Repeated power taps and Crown input during a power transition are ignored.
Off-state Crown drafts stay local until power-on, which combines power and the
draft. Power-on without a draft preserves even below-range reported brightness.
Dimming is disabled in non-white mode; power stays available.

Timeout updates status and cancels the adapter immediately, but the worker keeps
ownership until the adapter actually finishes. No read or write can overlap an
uncooperative cancelled operation. Potentially applied writes stop and discard
the queue, then reconcile through one fresh read without replay. Backgrounding
invalidates callbacks, cancels work, and drops drafts and unsent intents.
Foreground activation reads fresh state; simultaneous activation/refresh calls
coalesce. `deactivateAndWait()` and `waitUntilIdle()` provide a drain gate for
configuration replacement/removal.

Rate limits drop the queue and expose a monotonic cooldown deadline. Retry-After
is honored; missing/invalid Retry-After uses the policy fallback. Only an explicit
refresh after the deadline resumes control. Authentication, missing-device, and
unsupported-schema/brightness failures require setup. Last reported state remains
visible while stale, failed, or unconfirmed.

Simulation adds `.rateLimited` (two-second Retry-After) and `.uncertainWrite`
(applies the patch, throws uncertainty, then allows a successful state read).

## Validation evidence

Final command: `make test` in this checkout, which runs
`swift test --package-path Packages/BulbCore --scratch-path build/swift-package`.
Outcome: **35 tests in 3 suites passed, zero failures, 1.592 seconds**.
Compiler/test log: `/private/tmp/bulb-assist-stream-a/build/logs/stream-a-core.log`.
`git diff --check` also passed. Swift compilation required the normal compiler
cache access; the test scratch directory remained checkout-local.

The suite includes 19 coordinator tests using a manually advanced monotonic clock
and a gated controller that records starts, completions, cancellations, and maximum
concurrency. It proves shared live one-second spacing, rapid reversals/endpoints,
one latest pending value during slow writes, final deduplication, obsolete readback
and obsolete timeout protection, power-off ordering, bounded confirmation, deadline
expiry while spacing, uncertain/cancelled/timeout writes without replay, cooldown
and fallback behavior, foreground reconciliation, coalesced reads, and actual
adapter drain before configuration replacement. Every gated overlap check reports
maximum concurrency one. Existing behavior tests retain off-state drafts,
below-range brightness, non-white mode, normal confirmation, rejection, offline,
numeric bounds, and lifecycle regression coverage. Shared-contract tests also pass.

No simulator sessions, native platform tests, credentials, or physical lamp
operations were used by Stream A. Root owns both app builds and the Watch UI M2
integration gate; physical M3/M4 gates remain separate.

## Integration handoff

Render all `RemoteStatus` cases: `connecting`, `ready`, `updating`, `stale`,
`unconfirmed`, `cooldown(until: TimeInterval)`, `setupRequired(BulbFailure)`, and
`failed(BulbFailure)`. The cooldown deadline is expressed in the injected clock's
monotonic seconds and is enforced by `refresh()`. Stale retains the last reported
snapshot during backgrounding and foreground/manual reconciliation; controls remain
disabled until a successful read.

Preserve existing selection, idle commit, refresh, activation/deactivation, and
power entry points. Invalidate and await `deactivateAndWait()` before constructing
a coordinator for a replacement configuration. `refresh()` returns after its
requested/coalesced read has settled, so direct Watch verification can inspect
`status` and `reportedState` from the same coordinator.

No shared-contract, app-view, project, Makefile, or other stream file changes are
requested beyond rendering these states and using the drain gate. Uncooperative
adapters can keep a drain call pending until they finish; the UI timeout still
arrives at its deadline, and safety takes priority over starting another request.
