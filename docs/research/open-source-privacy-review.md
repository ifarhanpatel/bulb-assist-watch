# Open source privacy review

Reviewed: 2026-10-09 (Asia/Kolkata). **Disposition: publish only the reviewed fresh
source snapshot; do not expose the existing private history.**
Baseline private HEAD: `c92ebcad459c804a469cdf1551f8a4109f2c989e`.

## Scope and method

The baseline inventory contained 111 tracked files and 17 reachable commits.
An initial heuristic reviewed 139 unique UTF-8 blobs for credentials, local
paths and personal/device identifiers. Dedicated Gitleaks 8.30.1 subsequently
scanned all local refs with `--all --full-history -m` (17 commits), upstream
rules and an added regional Tuya bearer-key rule. Reports were redacted 100%
and kept outside the repository. No real Tuya key was found in those scans.
Scanner absence alone is not proof of absence of every secret format.

The GitHub connector verified the repository is private, owned by the expected
account, with `main` and `codex/parallel-integration` matching local heads. No tags,
releases, issues, pull requests or Actions runs were returned. Wiki, Pages and
discussions are disabled. No additional release/issue/run attachment surface was
therefore exposed in this inspection. GitHub CLI authentication was unavailable;
the connector supplied the remote evidence.

All 34 tracked PNG paths were visually reviewed. They cover 33 unique binary
blobs, which also account for all historical binary blobs. No visible key,
account identity, home/location detail or notification was found. Known generic
bulb/model labels and intentionally retained validation timestamps/region/state
are not treated as credentials.

## Findings and dispositions

| Finding | Disposition |
| --- | --- |
| Real API credentials | None identified by the scoped scans/manual review; no key was rotated or live credential used for validation. |
| Synthetic test credentials | Two exact fake values scoped to their fixture paths in `.gitleaks.toml`. Fake transports are injected. No broad file/rule suppression. |
| Pen `fileToken` | Gitleaks detects it in `design/bulb-assist.pen` at private root commit `2062817a0298b73d490c49462b909dcead38ee69`. Exclude the whole canvas and existing Git history from publication; retain the finding in private history. |
| Personal signing defaults | Removed from generated/shared project settings. Optional ignored `Config/Local.xcconfig` holds the owner's local values; the clean source uses `org.example` and no team. |
| Author/committer email | One non-noreply address in private history. The fresh snapshot excludes Git metadata; the future public initial commit needs a verified public/noreply identity. Attribution to Farhan Patel remains in LICENSE. |
| Image metadata | Reviewed EXIF/text described screenshots and numeric rendering metadata, with no location/serial/path. Removed unnecessary EXIF/iTXt chunks from 28 PNGs; compressed pixel data stayed byte-identical. Other chunks/provenance retained. |
| Diagnostic reports | Reviewed historical reports omit keys and device IDs; region, times and simple state intentionally retained. New helper reports default to ignored `build/reports/`. |
| Ignored/private files | Publication uses a file-by-file manifest, not a folder zip or Git archive of the private branch. Local signing, build products, hidden user settings and canvas are excluded. |

### Design-sharing identifier evidence

The supported editor was used to inspect canvas assets (Inter and Lucide).
Static review of the installed Pen 1.2.16 client shows `fileToken` is a locally
generated UUID, distinct from the session bearer and public `shareToken`.
Owner comment/status requests attach separate session authentication; anonymous
viewers use a separate share token. The client does not prove server-side
ownership enforcement. The [official sharing documentation](https://docs.pen.dev/core-concepts/sharing)
explains that a share link allows viewing/downloading.

It would be unjustified to label the UUID unconditionally harmless. Excluding
both the document and the old history avoids publishing it without probing a
private service or changing sharing settings. No UUID/session value was sent to
an external endpoint for this audit. Existing private history still yields one
scanner finding by design. There is no allowlist for it.

## Runtime review

The [setup UI](../../Apps/iPhone/SetupView.swift) uses secure entry and clears its
key field when discovery starts. Both [Keychain stores](../../Apps/Shared/Provisioning/KeychainCredentialStore.swift)
use non-synchronizing `WhenUnlockedThisDeviceOnly` records. Active
[WatchConnectivity](../../Apps/Shared/Provisioning/WatchConnectivityBridge.swift)
provisions the selected configuration; it does not queue keys in background
application context/user-info. Keys necessarily exist in memory during use.

The [Tuya client](../../Packages/BulbCore/Sources/BulbCore/Tuya/TuyaClient.swift)
sends the bearer and target ID to the selected regional HTTPS host.
[Native transport](../../Packages/BulbCore/Sources/BulbCore/Tuya/TuyaHTTPTransport.swift)
uses an ephemeral session without cookie/cache persistence and rejects redirects.
Source review found no app telemetry/backend or native logging of raw keys/bodies.
Debug counters are in-memory measurements, not physical latency measurements.

Replacement/removal use revisioned records and active acknowledgements. A pending
Watch removal may leave its old key stored; a tombstone persists after local
deletion. Provider revocation is separate, and uninstall is not an erasure
promise. Helper wrappers were reduced to local hidden input and stdin transfer, with unused
environment/GitHub-secret setup code removed. Reports redact known keys and IDs;
terminal device names remain
a sharing risk and are documented. No helper was run with a real key here.

Eight native platform tests verify storage/replacement/deletion, tombstones,
protection attributes, message encoding and acknowledgements. Core and UI tests
exercise synthetic flows. These are not a live network-capture audit, an OS
forensics audit, or an independent penetration test. [PRIVACY.md](../../PRIVACY.md)
keeps those limits explicit.

## Final candidate

The [validation record](../validation/open-source-readiness.md) records the exact
baseline, current test results and export checks. `SOURCE_MANIFEST.json` and the
adjacent `SHA256SUMS` identify the final source/archive bytes. The
[release procedure](../release.md) requires a fresh public initial commit and a
final scan, rather than exposing the private branches. Any content changes after
export require a new candidate and scan.
