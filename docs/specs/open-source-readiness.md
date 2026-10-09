# Open source readiness checklist

Updated: 2026-10-09 (Asia/Kolkata). Status: source publication complete. The [public repository](https://github.com/ifarhanpatel/bulb-assist-watch)
contains an independent, experimental source snapshot. The original private
history was excluded.
See [release procedure](../release.md) and [validation](../validation/open-source-readiness.md).

The owner confirmed a personal project with no employer/client material and
requested implementation of this plan. MIT applies to project material; vendor
service conditions remain separate. M4 hardware/daily-use work remains a
[separate product milestone](tasks.md#m4--hardware-and-personal-daily-use-readiness).

## Privacy

- [x] Inventory tracked files, all local reachable refs and accessible remote surfaces.
- [x] Scan 139 historical text blobs heuristically and all 17 reachable commits with Gitleaks 8.30.1; redact reports and disposition findings.
- [x] Review all 34 tracked PNG paths and all 33 historical binary blobs; remove unnecessary screenshot metadata without changing pixels.
- [x] Separate personal signing and bundle configuration into an ignored local override.
- [x] Review credential entry, Keychain, active Watch provisioning, regional HTTPS, logging, helpers, replacement/removal and revocation semantics.
- [x] Verify GitHub visibility, branch/ref coverage and absence of release/issue/Actions publication artifacts through the connector.
- [x] Exclude the unresolved design-sharing identifier and private author metadata by preparing a fresh snapshot without the canvas or Git history.
- [x] Move new diagnostic reports to ignored build output and document safe sharing.
- [x] Re-scan the final publication set and verify manifest/archive boundaries.

No real credential was identified, so rotation was not performed. The private
history still has one unresolved Pen sharing-identifier finding; it has not been
silenced or declared harmless. Do not flip the existing repository to public.
Details: [privacy review](../research/open-source-privacy-review.md).

## Ownership, Wipro and Tuya

- [x] Record the owner's no-employer/client-material attestation.
- [x] Inventory dependencies and asset provenance; preserve Inter/Lucide notices and icon generation provenance.
- [x] Verify independent Swift calls to documented Tuya End User REST, with no bundled vendor SDK, firmware or extracted app implementation.
- [x] Review official Tuya API/service terms and SmartLife terms; distinguish source publication from cloud eligibility, native REST, WebSockets and binary/commercial distribution.
- [x] Review relevant Wipro Consumer Lighting website, app-listing and warranty evidence; avoid unrelated Wipro IT terms and unsupported warranty claims.
- [x] Record unavailable account-specific/key-issuance terms as a runtime eligibility limitation, not permission or proof of a source-publication prohibition.
- [x] Keep original branding and factual model references; add non-affiliation language without certification claims.
- [x] Apply the proposed standard MIT license, retaining third-party notices separately.
- [x] Record a scoped recommendation: no concrete independent-source publication blocker found; fresh snapshot subject to privacy exclusions.

The actual agreement accepted by a user's account/key was not inspected. Each
user must review the terms shown to them. Signed binaries, hosted services,
commercial operations or a different integration require a new assessment.
This is evidence review, not a legal opinion. See the
[cited legal report](../research/open-source-legal-review.md).

## Public documentation

- [x] Rewrite README with purpose, experimental status, screenshot, simulator quickstart, cloud dependency and license.
- [x] Add setup with own-team signing, unique IDs, runtime requirements, key entry and provisioning/removal.
- [x] Document exact schema, white-mode constraints, one-bulb scope and tested-versus-expected compatibility.
- [x] Add PRIVACY, CONTRIBUTING and SECURITY, with a truthful reporting fallback and no invented contact.
- [x] Add asset notices and keep design previews distinct from native validation screenshots.
- [x] Reconcile original specs/historical research with current public scope, preserving hardware limitations.
- [x] Add sanitized bug and compatibility issue templates.
- [x] Document the fresh-snapshot release procedure and proposed release notes.

Private vulnerability reporting is enabled for the public repository. The
fallback requests private contact without revealing report details if GitHub
removes or hides the reporting control.

## Verification

- [x] Run 89 core tests and both simulator builds from a clean source copy with no personal signing override.
- [x] Run eight platform and three companion UI tests with synthetic credentials.
- [x] Complete all ten Watch UI tests and record results.
- [x] Verify XcodeGen regeneration is idempotent.
- [x] Add CI for core tests, simulator builds, exporter checks and secret scans; no live credentials or pull-request write permissions.
- [x] Implement an explicit publication manifest and reproducible archive exporter, with negative boundary tests.
- [x] Check final Markdown targets, script/workflow syntax, scanner canary, final source scan and reproducible archive integrity.
- [x] Prepare concrete source-only release notes and publication steps.

## Publication actions

- [x] Owner authorized public publication of the exact reviewed archive/checksum.
- [x] Create a fresh repository/initial commit with a GitHub noreply author identity; keep private history and excluded canvas private.
- [x] Enable and verify private vulnerability reporting before announcing the public repository.
- [x] Run hosted CI on the initial public commit and confirm required checks pass.

The public source repository is live. The original repository remains private;
no vendor contact or binary release was part of publication. M4 hardware and
daily-use validation remains open. See the [release record](../release.md).
