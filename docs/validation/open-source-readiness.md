# Source-release validation

Date: 2026-10-09 (Asia/Kolkata).
Private baseline: `c92ebcad459c804a469cdf1551f8a4109f2c989e`, branch
`codex/parallel-integration`. The initial public source was built from the
reviewed export, then committed as [`95de7d9`](https://github.com/ifarhanpatel/bulb-assist-watch/commit/95de7d98a89693ae77828a40b2024094dc117e81).
The private baseline commit is not part of public history.

## Local results

Tests ran from a separate clean source copy, excluding personal signing settings,
credentials and local build output. Simulator runtime was iOS/watchOS 26.4 with
Xcode 27.0 (27A266a). iPhone tests used iPhone 17 Pro; Watch tests used Apple Watch
Series 11 (46mm). Core tests ran on the host. No live API call was needed.

| Check | Result |
| --- | --- |
| `make test` | 89 tests passed across seven suites |
| `make build` | Both iOS and watchOS simulator builds passed without a development team |
| `make test-platform` | Eight native Keychain/provisioning tests passed |
| `make test-iphone-ui` | Three companion UI tests passed |
| `make test-watch-ui` | Ten Watch UI tests passed |
| XcodeGen 2.42.0 regeneration | Byte-identical checked-in project/schemes after regeneration |
| Publication exporter regression tests | Three passed: forbidden paths; symlinks/duplicates; reproducibility and archive boundary |
| Shell / Python / workflow syntax | Bash syntax, Python AST and YAML parsing passed; both helper wrappers passed synthetic hidden-input/stdin/output-path checks and reject non-interactive runs |
| Local Markdown targets | All 33 published Markdown files checked for missing/excluded local targets |
| Gitleaks 8.30.1, private history | 17 commits scanned; one unresolved canvas sharing identifier intentionally excluded from the public snapshot |
| Gitleaks 8.30.1, final public source | No findings with default rules plus the scoped Tuya rule |
| Scanner detection check | Four cases passed: exact fixture allowed; same value outside its file detected; new key in fixture detected; upstream generic-key rule still detects |
| Archive/manifest integrity | Repeated exports byte-identical; file hashes, file set and zeroed owner/time metadata verified |

Platform tests exercise real simulator Keychain attributes, persistence,
replacement/deletion and acknowledgement contracts. Core/UI tests use fake
transports and synthetic credentials; they do not prove physical device or cloud
behavior. Hardware evidence stays in [M3 integration](parallel/native-integration.md)
and the unfinished [M4 run sheet](m4/hardware-run.md).

## Changes and review boundaries

Personal signing moved to ignored `Config/Local.xcconfig`, while the shared
configuration uses a replaceable bundle prefix. The public namespace is
`org.example`; physical installs use the contributor's own team/prefix.
Diagnostic reports now default to ignored build output. Existing image pixels
were preserved while redundant EXIF/text metadata was removed.

Added MIT licensing, original/third-party asset provenance, public setup and
compatibility guidance, privacy/security/contribution documents, sanitized issue
templates, a reviewed publication manifest and deterministic exporter. CI pins
checkout to a verified commit and Gitleaks to a verified version/checksum, uses
read-only repository permissions, and needs no bulb credentials. The first hosted
[Actions run](https://github.com/ifarhanpatel/bulb-assist-watch/actions/runs/37965853690)
passed both Swift and secret-scanning jobs.

All 51 app/test/build/config files match the tested clean source copy byte for
byte. The diagnostic wrappers were simplified to remove unused environment and
GitHub-secret helpers; their tests use a fake Python process and make no network
request. No runtime control behavior or supported device schema was expanded. Local
validation is not legal clearance, a full network security audit, a claim of
unrestricted provider service access, or a completed M4 product milestone.
See [legal evidence](../research/open-source-legal-review.md) and
[privacy dispositions](../research/open-source-privacy-review.md).

## Publication status

The [source repository](https://github.com/ifarhanpatel/bulb-assist-watch) is
public. Its first commit passed the hosted CI run above, and private vulnerability
reporting is enabled. The original development repository and its history remain
private because they retain the design-sharing finding and personal metadata.
No old history was rewritten, no live key was rotated, no vendor was contacted,
and no signed binary was distributed. See the [release record](../release.md).
