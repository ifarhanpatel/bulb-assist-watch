# Stream B — Tuya adapter

Date: 2026-10-09. Base: shared-contract commit `0ffaaea`.
Worktree: `/private/tmp/bulb-assist-stream-b`.
Branch: `codex/m3-tuya-adapter`. VoiceOver work excluded.

## Implemented behavior

Added `BulbCore/Tuya` discovery and controller implementations with an injected
HTTP transport and credential supplied at construction. Region hosts, bearer
authentication, endpoint shapes, model JSON string, property JSON string, and
documented error codes were checked against the official
[Tuya End User API reference](https://www.tuya.ai/developer/docs) on 2026-10-09.
The Python helpers and redacted capability record supplied the verified bulb
schema: power `rw/bool`, brightness `rw/value/10...1000/step 1/scale 0`, and an
enumerated readable mode including `white`.

`URLSessionTuyaTransport` uses an ephemeral session, no cookies/cache, a five
second request/resource timeout, and a delegate that rejects every redirect.
There are no application retries, pacing sleeps, command readbacks, or hidden
schema reads inside controller operations. Each valid controller read or apply
issues exactly one request. Invalid local prerequisites issue zero requests.

Discovery rejects malformed lists and duplicate IDs, retains devices with the
same name as distinct selections, and percent-encodes IDs as single path segments.
Controller construction validates the model in one request. Reported reads
validate the selected device ID, strict Boolean fields, integer brightness
10...1000, online state, and modeled mode. Brightness below 100 stays unchanged
in reported state; observation time is injectable. Unknown modes and malformed
values fail safely.

Commands contain only explicit `switch_led` and/or `bright_value` patches.
Power-on without a draft preserves brightness. Power-off omits brightness.
Brightness requires a successful white-mode read. Power-on after a non-white
read omits a draft; standalone dimming is rejected locally in that mode.
Mode and color temperature are never written.

HTTP/API failures map to shared typed outcomes without exposing provider
messages, credential values, selected IDs, raw bodies, or underlying URL errors.
Retry-After accepts nonnegative seconds and HTTP dates. Issued writes with
transport failures, timeouts, cancellation, server errors, or malformed success
responses are uncertain and require reconciliation. Known rejection/auth/rate
limit/missing-device outcomes remain definite. Preflight cancellation issues no
request; cancellation after issue waits for transport completion and returns an
uncertain write, including when a transport returns late success.

## Integration APIs

```swift
try TuyaDiscovery(apiKey: key, transport: transport) // transport defaults to URLSessionTuyaTransport()
try await discovery.listDevices()
try await discovery.capabilities(for: selected)
let controller = try await discovery.makeController(for: selected)
try await controller.readState()
try await controller.apply(command)
```

`TuyaHTTPTransport.send(_ request: URLRequest)` returns `TuyaHTTPResponse`
with status, string headers, and Data body. Both types are public for coordinator
integration fixtures. A `now: @Sendable () -> Date` argument can make observation
and HTTP-date Retry-After deterministic.

The factory model request is outside the coordinator. Construction/verification
must leave at least the live one second spacing before the initial detail read;
the integration owner owns that pacing and subsequent shared read/write budget.
Do not invoke discovery/model checks on every command. A new configured Watch
controller validates its model on construction before the initial direct read.

The adapter uses the last successfully reported mode; an external Smart Life
mode change can occur between read and write. Keeping a single request per
command prevents a hidden extra detail check. The coordinator performs initial,
foreground, explicit-refresh, and confirmation reads and gates UI dimming;
payloads preserve mode even in that race. Credentials are never persisted by the
adapter; the setup/platform stream owns secure storage.

## Validation gate

Command: `make test` in the isolated worktree, using its
`build/swift-package` scratch directory. Final result: **38 Swift Testing tests
in 3 suites passed, zero failures**, 0.010 s test execution; build 3.40 s.
This includes 22 Tuya tests and the 16 baseline/shared tests. The separate XCTest
summary reports zero XCTest tests because the package uses Swift Testing.

Coverage includes all seven region hosts, authorization/headers/timeouts,
selection, escaped paths, JSON-string fields, exact power and brightness patches,
schema rejection, readback without clamping, non-white and unknown mode behavior,
HTTP/API failures, strict envelope parsing, rate limits and Retry-After seconds
and dates, offline/missing devices, rejected redirects, timeout/cancellation,
late success after cancellation, oversized bodies, definite/uncertain writes,
no retries/hidden requests, and safe error/object descriptions.

Fixtures are synthetic Swift values, isolated in the Tuya test directory; no
Package.swift resource changes are needed. Tests never use a live credential,
connect to the provider, or alter the lamp. The redirect test invokes the actual
URLSession delegate rejection policy and checks injected redirect HTTP responses;
it does not claim a live redirect/network test. No simulator sessions were run.
Both native target builds and coordinator integration remain the integration
owner's gates. Physical Watch HTTPS and lamp outcomes remain the M3 physical gate.

One initial sandboxed compilation attempt was unable to write the system Swift
module cache. Authorized `make test` with cache access then compiled and passed.
No implementation failures remain. No shared contract or project changes requested.
