# Initial source release

The [public source repository](https://github.com/ifarhanpatel/bulb-assist-watch)
was created on 2026-10-09 from a fresh snapshot. It includes the app, tests,
reviewed images, MIT license, notices and documentation. It excludes signing
overrides, credentials, build output, the private Git history and the editable
design canvas.

## Why a fresh snapshot

The private development history contains a non-noreply author email, old signing
identifiers and a Pen document/sharing identifier. The latter is distinct from
an API key, but its server-side access behavior has not been independently proven.
It remains an unresolved privacy concern in that history. The public snapshot
excludes it and the history containing it; no history rewrite is needed.
**Do not simply change the existing repository's visibility to public.**
See the [privacy audit](research/open-source-privacy-review.md).

## Build the publication set

```sh
python3 scripts/check-docs.py
python3 scripts/export-source.py
```

The exporter uses the explicit reviewed list in `scripts/public-files.txt`.
It rejects sensitive path types, local signing settings, symlinks and traversal.
New files require an intentional manifest update and review. It creates an
ignored `build/release/candidate-…/` directory containing:

- `bulb-assist-source/`: clean source with no `.git` directory;
- `SOURCE_MANIFEST.json` inside that directory: SHA-256 for every included source file;
- `bulb-assist-source.tar.gz`: reproducible archive without machine paths or owner metadata;
- `SHA256SUMS`: the archive checksum.

The same file contents/modes produce the same archive bytes. A new export gets
a new directory, so earlier candidates are not silently overwritten. Archive
checksums identify the exact candidate without a circular self-hash in this document.

From the extracted source directory, run:

```sh
make test
make build
make test-platform
make test-iphone-ui
make test-watch-ui
```

Serialize simulator runs and use the destinations in [setup](setup.md). Scan
the extracted source with [Gitleaks 8.30.1](https://github.com/gitleaks/gitleaks/releases/tag/v8.30.1):

```sh
gitleaks dir --config=.gitleaks.toml --redact=100 --no-banner .
```

The rules extend upstream defaults and permit only exact synthetic keys in two
specific fixture files. They do not suppress the private canvas finding. Never
commit a raw scanner report. The CI history scan continues to flag the private development history if run
there; it passed on the new public snapshot history.

## Publication record

The owner authorized the public source release. The approved archive SHA-256 was
`49a6a973d6f5b05291dcdc5e119d0895d6e3503eafb2c920d4f1a1814f3f6f84`.
The fresh public initial commit is
[`95de7d9`](https://github.com/ifarhanpatel/bulb-assist-watch/commit/95de7d98a89693ae77828a40b2024094dc117e81),
authored with the owner's GitHub noreply identity. Its 136-file tree contains no
private canvas or local signing override. The original `bulb-assist` repository
remains private.

[GitHub Actions run 37965853690](https://github.com/ifarhanpatel/bulb-assist-watch/actions/runs/37965853690)
passed the secret scan, core tests, simulator builds, documentation links and
source export. Private vulnerability reporting is enabled in the public
repository. This document was updated after that initial commit.

Future source changes should pass the same checks. Do not upload signed binaries
or claim production readiness as part of this source-only release. Reassess provider
and Apple distribution terms before binary release, hosting, monetization or
shared credentials. The scoped review found no concrete blocker to independent
source publication; account-specific API use remains subject to its own terms.

## Proposed release notes

Initial experimental source release: a SwiftUI iPhone companion and Apple Watch
remote with Crown brightness, power, capability validation, paced direct Tuya
REST control, Keychain storage and acknowledged paired-device provisioning.
Includes credential-free prototypes, synthetic tests, portable signing setup,
privacy/security guidance and CI. Tested hardware is one Wipro NS9001; other
models with matching schemas are candidates. Sustained-use and physical latency
validation remain open. No signed application binary or cloud entitlement is
provided.
