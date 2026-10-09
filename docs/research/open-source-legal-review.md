# Wipro and Tuya legal review for open source release

Reviewed: 2026-10-09 (Asia/Kolkata). All external sources below were accessed on
that date. This is a scoped evidence review for release planning, not legal
clearance or an opinion on enforceability in every jurisdiction.

## Readiness conclusion

**Continue preparation for an independent experimental source release.** The
focused follow-up found no concrete legal blocker to publishing the project's
own code and reviewed assets under that scope. This is a reasoned assessment of
the evidence below, not a guarantee of unrestricted API use or legal clearance.

The assessed release distributes source without vendor software, shared keys,
vendor logos, a hosted control service, or claims of endorsement. Consumers build
locally and supply their own authorized credentials. The project's open-source
license covers only rights the project can grant.

| Activity | Current assessment |
| --- | --- |
| Publish independently implemented source and original project materials | Proceed after provenance/privacy checks; no identified vendor publication prohibition applies on the facts inspected. |
| Personal live control using one's own key | Subject to provider/account conditions; key-specific agreement, exact quota and eligibility remain unverified. |
| Publish signed binaries or offer a hosted/paid service | Outside this assessment; resolve distribution/service conditions first. |
| Reuse vendor software, artwork or logos | Outside this release; separate rights would need review. |

Unknown account-specific terms remain unknown. Document that limitation instead
of interpreting silence as permission or treating it as evidence that publishing
our own source is prohibited. Pause if evidence emerges that the code/assets were
copied without rights, an accepted agreement restricts this publication, or the
release would distribute credentials or vendor services.

## What this repository actually implements

- [TuyaClient.swift](../../Packages/BulbCore/Sources/BulbCore/Tuya/TuyaClient.swift)
  is a native Swift REST client using a user-supplied `sk-…` bearer key. It calls
  regional Tuya HTTPS hosts under `/v1.0/end-user/`.
- [Discovery](../../Packages/BulbCore/Sources/BulbCore/Tuya/TuyaDiscovery.swift)
  lists devices and inspects their model; the
  [controller](../../Packages/BulbCore/Sources/BulbCore/Tuya/TuyaBulbController.swift)
  reads state and issues power/brightness properties. The transport uses Apple's
  URLSession. This is cloud control, with no project-operated backend.
- [Package.swift](../../Packages/BulbCore/Package.swift) has no external package
  dependencies. The release inventory found no bundled Tuya/Wipro SDK, firmware,
  binary, or font. This reduces redistribution questions associated with vendor
  SDKs; it does not establish the provenance of every source line or asset.
- The owner stated: “Personal project; no employer or client material.” Record
  this as an owner attestation. The icon's ImageGen provenance is recorded in
  [generation.txt](../../design/branding/generation.txt); other assets still need
  the separate publication inventory and privacy review.

## Tuya evidence and applicability

### The API being used

The [Tuya.AI End User API reference](https://www.tuya.ai/developer/docs) describes
the same bearer authentication, regional hosts, device-list/model/detail endpoints
and property command endpoint used here. It labels the service a trial with rate
limits; the inspected page does not state a general numerical device-control quota.
Its explicit mobile/browser prohibition concerns WebSocket connections. This code
uses REST, not WebSockets; do not silently broaden that prohibition to REST or
treat its limited scope as affirmative REST distribution permission.

The [developer landing page](https://www.tuya.ai/developer) invites users to build
smart-home applications and links an official
[MIT-labelled CLI repository](https://github.com/tuya/tuya-smart-control-cli).
This is evidence of a supported developer surface, not a grant of cloud-service
rights to Bulb Assist or its users. This project does not bundle that CLI.

The official [Tuya OpenClaw skills repository](https://github.com/tuya/tuya-openclaw-skills)
implements the same End User endpoints and carries a complete
[MIT license](https://github.com/tuya/tuya-openclaw-skills/blob/master/LICENSE),
copyright 2026 Tuya. Its README separately warns that API endpoints are in trial
with usage restrictions still being announced. This supports the distinction
between publishing client code and granting service access; neither that license
nor the CLI's MIT metadata overrides an API user's contract.

### Terms linked by that API reference

[Tuya.AI Terms of Use](https://www.tuya.ai/policies/service), effective December
20, 2025, are linked directly from the API reference. Relevant clauses:

| Clause | Evidence and implication |
| --- | --- |
| 1.1–1.2; 2.6 | Broad software/services scope; feature-specific agreements may also apply. |
| 3.3 | Private, non-commercial service use; restricts offering/transferring Services and requires authorization for commercial operation. |
| 3.7; 5.1(2)–(4) | Protect accounts, access only authorized data, and avoid server overload. |
| 6.1–6.4; 8.4 | Reserves vendor IP/brands; restricts copying, reverse engineering and redistribution of vendor software/services; disclaims third-party software derived from it. |
| 11.1–11.2 | Specifies Delaware law and arbitration seated in Singapore. |

Applicability to independently written REST-client source remains unresolved.
Verify provenance and the specific API agreement; publishing a free client must
not automatically be equated with redistributing vendor software or offering its
Services.

### Avoid substituting a different Tuya product's terms

The [general developer-site terms](https://auth.tuya.com/policies/service), last
updated November 4, 2021, identify website/platform scope in §1.1 and additional
service agreements in §§1.2 and 4.3. They also reserve vendor IP (§6). They are
relevant background, not evidence that the newer End User API has identical
entitlements.

Likewise, [Request Tuya Cloud API Key](https://developer.tuya.com/en/docs/developer/apply-cloud-api-key?id=Kff30z8sv62ah),
updated March 24, 2026, describes a cloud project with Client ID/Secret, UID and
IoT Core subscriptions. Those are different credentials from this app's End User
bearer key. Do not transplant that product's trial, pricing, or distribution rules
into the setup guide.

The current [Get API Key destination](https://auth.tuya.ai/login?loginSource=web_hey_tuya)
was inspected without signing in. Its public login screen offered Tuya/SmartLife
app sign-in but did not expose the subsequent key-issuance agreement. No account
was created, no key was requested, and no terms were accepted. The exact terms
shown to this owner's region/account at issuance remain an evidence gap.

### SmartLife account agreement

The [SmartLife website](https://www.lifeaiot.com/), linked by its official app
listing, publishes [SmartLife Terms of Use](https://app-h5-us.iotbing.com/developerapp/protocol/192c3c61e4400032?lang=en)
with Volcano Technology Limited. No effective date was displayed. Section 3.3
limits service use to private/non-commercial purposes. Sections 6.4 and 8.4
restrict redistribution or derivation of the vendor's app/services; §6.2 reserves
branding rights. The inspected project implements public REST calls independently
and does not contain that app or its source. No evidence establishes it as
vendor-app-derived software. These clauses therefore do not establish a source
publication blocker on the present record, while remaining relevant to runtime
and any future service offering.

The [official SmartLife guide](https://developer.tuya.com/en/docs/iot/user-manual-for-tuya-smart-v3177?id=K9obrofrfk4sk)
requires an agreement during registration. The exact version accepted by this
owner was not inspected; the public terms cannot prove their account history.

## Wipro evidence and applicability

Use **Wipro Consumer Care & Lighting / Wipro Enterprises** sources for this bulb,
not unrelated Wipro IT-services policies. The official
[Wipro Next Smart Home listing](https://play.google.com/store/apps/details?id=wipro.com&hl=en_US)
identifies Wipro Enterprises Private Limited and links Consumer Lighting support
and its [privacy policy](https://www.wiproconsumerlighting.com/privacy-policy).
That privacy-policy link does not establish an app/API license.

The [Consumer Care & Lighting disclaimer](https://wiproconsumercare.com/disclaimer/)
expressly concerns its website. Its content/IP paragraphs restrict copying site
materials without written permission and assert consent requirements for use of
the Wipro trademark. Avoid incorporating vendor logos, product marketing photos,
manuals, or copied app artwork. These website terms alone do not settle whether a
separate client may control an owned bulb via Tuya.

The [Consumer Lighting warranty policy](https://www.wiproconsumerlighting.com/warranty-policy)
lists exclusions including unauthorized repairs/modifications and uses outside
the manual's intended conditions. It does not specifically resolve whether
SmartLife pairing or this REST client affects an NS9001 warranty. Do not promise
either warranty preservation or automatic invalidation.

No public Wipro Next API authorization or current app user agreement specifically
covering this integration was located in the inspected official site/app-listing
paths. Obtain the agreement actually applicable to the owner's account before
closing that question. The absence of a public agreement is not permission.
The current code does not log into Wipro Next or implement a Wipro private API;
do not imply that Wipro Next credentials/devices are automatically supported.

## Generated icon rights

The recorded prompt describes a generic bulb/dimmer mark with no vendor marks or
reference artwork. [OpenAI's individual Terms of Use](https://openai.com/policies/terms-of-use/),
effective January 1, 2026, assign OpenAI's rights, if any, in output to the user,
to the extent permitted by law; they retain user responsibility for content and
warn that output may not be unique. The
[Services Agreement §4.1–4.4](https://openai.com/policies/services-agreement/), also
effective January 1, 2026, provides the corresponding customer-output allocation
for business/API use. The originating account's exact contract was not inspected.

These provisions support use of the generated project icon; they do not establish
exclusive copyright, trademark clearance, or freedom from every third-party claim.
Retain generation provenance and grant only rights the project holds. No specific
icon-rights conflict was identified in this review.

## Source license and presentation

The release uses the standard MIT license for material the owner can license. Keep
third-party service conditions in documentation, separate from that license.
Adding a non-commercial restriction to the code would conflict with the
[Open Source Definition, §6](https://opensource.org/osd).

Retain **Bulb Assist** as the project name and use original artwork. A suitable
proposed description is: “An independent experimental Apple Watch remote for
supported Tuya bulbs; tested with Wipro NS9001.” Add an accurate statement that
the project is not affiliated with or endorsed by Wipro or Tuya. Avoid certification
badges and vendor logos. These are risk-reduction recommendations, not a trademark
clearance search.

Vendor trademark clauses should not be conflated with statutory trademark scope.
For example, India's [Trade Marks Act, 1999, §30(1)](https://www.indiacode.nic.in/bitstream/123456789/1993/1/A1999-47.pdf)
recognizes limited identifying use subject to honest practices and protection of
the mark's character/reputation. Whether a particular presentation qualifies,
and whether contractual duties affect it, requires context; a disclaimer alone
does not decide it.

## Evidence and release checklist

- [x] Confirm the code uses the documented End User REST surface and no bundled
  vendor SDK; distinguish cloud project credentials from End User keys.
- [x] Record the owner's personal-project attestation and existing icon provenance.
- [x] Identify relevant public Tuya clauses and Wipro Consumer Lighting sources.
- [x] Inspect public SmartLife terms and official End User API open-source examples;
  distinguish vendor-app derivation restrictions from independent REST code.
- [x] Check OpenAI's public output-rights allocation for the generated icon.
- [ ] Record the actual account region, key-issuance terms/version, and any feature
  agreement. Store only redacted evidence; never include a key or login token.
- [ ] Record the actual accepted account agreements if needed to resolve runtime
  eligibility; current publication review does not claim those were verified.
- [x] Complete the scoped provenance inventory and apply the proposed MIT license
  under the owner's instruction to implement the readiness plan; retain
  [asset notices](../../THIRD_PARTY_NOTICES.md).
- [x] Review README, screenshots, icon, proposed repository description and examples for
  copied material, unsupported compatibility claims and implied endorsement.
- [x] Document cloud dependency, own-key setup, trial/limit uncertainty, authorized
  device access, key replacement/revocation, and provider-service limitations.
- [x] Decide the source-release scope using the recorded evidence and unresolved
  items. If applicable terms remain ambiguous, obtain targeted clarification or
  qualified legal review before making an unsupported permission claim.
- [ ] Reassess provider terms and platform distribution rules before publishing
  signed binaries, adding monetization, pooling credentials, or hosting a service.

## Draft clarification questions, if needed

These are prepared questions only; no vendor has been contacted.

**Tuya:** Which agreement governs `sk-…` End User REST keys for an India account?
May an independent iOS/watchOS app store the user's own key in device Keychain and
make direct HTTPS calls? Please distinguish publishing source, distributing a free
binary, and charging for an app/support. Are additional registration, attribution,
review, key-handling, quotas, or other distribution conditions required? Which
published clause or authorization covers each case?

**Wipro Consumer Lighting:** Which current Next Smart Home user agreement and
NS9001 warranty conditions apply to control through SmartLife/Tuya End User REST?
Does pairing this model with SmartLife affect support or warranty? Are there
requirements for truthful textual identification in an independent compatibility
list, without vendor logos or an endorsement claim?

Recheck this note when the access path, key type, SDK dependencies, project
branding, distribution channel, or commercial scope changes.
