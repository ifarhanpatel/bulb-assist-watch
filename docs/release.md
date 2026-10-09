# Initial source release

The publication candidate is a **fresh source snapshot**, not the existing
private repository or its history. It includes the app, tests, reviewed images,
MIT license, notices and documentation. It excludes signing overrides, credentials,
build output, Git metadata and the editable design canvas.

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
commit a raw scanner report. The CI history scan will continue to flag the private
development history; it is intended to pass on the new public snapshot history.

## Publication handoff

Publication has not been performed. After the owner explicitly authorizes it:

1. Verify the candidate's SHA-256 and manifest. Review the final
   [validation record](validation/open-source-readiness.md).
2. Create a new repository from the extracted source with a fresh initial commit.
   Use an owner-verified public or GitHub noreply author identity. Do not attach
   the old repository as an upstream or push its branches, tags or checkpoint refs.
   The existing private repository can remain the development archive.
3. Set the description to “Experimental Apple Watch remote for supported Tuya
   bulbs; tested with Wipro NS9001.” Retain the non-affiliation and MIT notices.
4. Enable private vulnerability reporting as soon as the public repository exists,
   before announcing it. Confirm **Security → Report a vulnerability** works and
   update SECURITY.md's staging sentence. No reporting email has been invented.
5. Require the new source checks to pass on GitHub. Local validation does not prove
   the first hosted Actions run has passed. Review branch protection appropriate
   to the repository and announce the experimental source scope.

Do not upload signed binaries or claim production readiness as part of this
source-only handoff. Reassess provider and Apple distribution terms before such
a release, hosting, monetization or shared credentials. The current review found
no concrete blocker to independent source publication; account-specific API use
remains subject to its own terms.

## Proposed release notes

Initial experimental source release: a SwiftUI iPhone companion and Apple Watch
remote with Crown brightness, power, capability validation, paced direct Tuya
REST control, Keychain storage and acknowledged paired-device provisioning.
Includes credential-free prototypes, synthetic tests, portable signing setup,
privacy/security guidance and CI. Tested hardware is one Wipro NS9001; other
models with matching schemas are candidates. Sustained-use and physical latency
validation remain open. No signed application binary or cloud entitlement is
provided.
