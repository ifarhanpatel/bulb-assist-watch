# Bulb Assist feasibility

Historical research record: use [setup](../setup.md) for the current contributor
path and the [2026-10-09 vendor review](open-source-legal-review.md) for the scoped
source-publication assessment. Earlier possibilities below are not all current
architecture or promised support.

Assessment date: 2026-10-08 (Asia/Kolkata).

## Verdict and project readiness

**Go for a personal Watch prototype: the basic physical bulb-control path is
proven.** The owner successfully paired the NS9001 with Smart Life, verified
phone/cloud control, and completed API discovery and an observed API command
test on 2026-10-08. All four commands were accepted, matched cloud readback, and
were physically confirmed by the owner; restoring the starting state passed too.
Smart Life's built-in Watch app lists this bulb as **not supported**, so a custom
Crown interface remains useful. The recommended prototype is Apple Watch → Tuya
End User HTTPS REST → NS9001, with an iPhone companion for setup. The validated
cloud path needs no local always-on bridge. Direct Watch operation, continuous
Crown responsiveness, outage recovery, and sustainable API access remain to be
validated. Four observed commands establish a working integration, not a
production reliability or latency guarantee.

### Hardware evidence reported by the owner

- **2026-10-08: Smart Life pairing succeeded.** Source: the owner's chat message,
  “Wipro bulb connected successfully to smart life app”. This confirms pairing
  for the owner's unit; it does not establish compatibility for every NS9001 revision.
- **2026-10-08: Phone and cloud control work.** The owner confirmed both tests
  from the preceding instructions, covering power/brightness in Smart Life and
  remote operation using mobile data.
- **2026-10-08: Smart Life lists the bulb as not supported for Watch control.**
  The owner clarified the earlier visibility report: “inside me section ->
  device -> i can see wipro bulb listed as not supported”. This supersedes the
  interpretation that appearing in the list made direct Watch testing available.
- **2026-10-08: API key obtained.** The owner reported successful key issuance.
  The key has not been shared with the agent.
- **2026-10-08: API discovery and schema check passed.** The owner ran the local
  probe; its [saved report](tuya-api-check.json) records authentication and device
  visibility passing, one online device, the India data center, and a parsed
  model. `switch_led` is a readable/writable boolean. `bright_value` is a
  readable/writable integer with minimum 10, maximum 1000, step 1, and scale 0.
  `work_mode` is readable/writable and includes `white`; it was reporting white
  mode. These are observed API schema values for the owner's unit.
- **2026-10-08: Physical API control passed.** The owner ran the observed control
  helper. Its [saved report](tuya-control-check.json) records all four operations
  passing API acceptance, matching state readback, and physical observation:
  power on with raw brightness 250, brightness 500, brightness 750, then power
  off. Restoration also passed all three checks. Starting state was off with
  stored brightness 1000, in white-light mode. No key or device ID is in the report.
- Recorded command elapsed times were 0.574, 0.937, 0.217, and 0.111 seconds.
  They include client pacing and stop at the API response; they do not measure
  physical-response delay, readback completion, or Watch-to-bulb latency.
- Watch tap-to-run scenes, custom Watch operation, and continuous dimming remain
  untested. The built-in Watch app's unsupported label did not prevent the
  successful developer API control experiment.

The initial local audit found a documentation-only workspace: product and technical
specs, a task list, an ADR, and earlier communication research. There are no
Swift sources, Xcode project, build configuration, or tests. The directory also
has no Git repository. Xcode 26.4.1 is installed and selected; device pairing,
signing, simulator runtimes, and the owner's Watch/OS versions were not verified.
The README's “ready for prototype” describes planning readiness, not working
software. [Product scope](../specs/product-spec.md),
[technical plan](../specs/technical-spec.md), [tasks](../specs/tasks.md).

| Area | Assessment | What changes the decision |
| --- | --- | --- |
| Crown UI, power button, simulated bulb | Feasible; low implementation risk | On-Watch interaction test |
| NS9001 pairing with Smart Life | Confirmed by the owner for this unit | Pairing gate passed |
| Smart Life phone power/brightness and cloud control | Confirmed by the owner | Consumer-app control gate passed |
| Existing Smart Life direct Watch support | Owner reports bulb listed as not supported | Built-in direct control unavailable in current setup; scenes are a separate untested option |
| Tuya End User API authentication and device discovery | Passed in the owner-run probe | Key lifetime and ongoing access terms remain unknown |
| Developer API power and brightness | Four physical commands plus restoration passed; raw brightness schema is 10–1000 | Repeated/interrupted commands and sustained reliability |
| Custom app without a local bridge | Cloud control path proven from the Mac | Direct Watch requests, key terms, and measured reliability |
| Smooth visible dimming | Unproven | Actual command-to-light latency and ordered final-value delivery |
| Long-term personal use | Conditional | Sustainable API access and acceptable signing/maintenance effort |
| General-purpose commercial product | Outside current scope | Multi-account onboarding, support, and commercial API terms would need a separate assessment |

Next: **custom Watch prototype → physical Crown and lifecycle tests → recovery
and sustained-use checks**. Basic desktop API feasibility is complete. The
production integration, credential lifecycle, and full Watch acceptance criteria
remain open; the recommendation is not an accepted production ADR.

### Local API discovery check

The feasibility investigation now includes a one-off helper:
[check-tuya-api.sh](../../scripts/check-tuya-api.sh), backed by
[tuya_api_probe.py](../../scripts/tuya_api_probe.py). Run the shell script in an
interactive terminal and enter the existing API key at its hidden prompt. The
key stays in process memory and is not saved. The helper discovers devices,
lets the owner select the bulb, and reads its detail and model using GET only.
It saves `docs/research/tuya-api-check.json` with IDs omitted and any echoed key
redacted. It does not send light-control commands.

Syntax and offline success/failure/redaction checks passed. The owner completed
the real API check, and the agent inspected its saved report. A discovered
writable property is capability evidence, not proof of a successful physical
command.

The control helper, [test-tuya-control.sh](../../scripts/test-tuya-control.sh), uses
[tuya_control_test.py](../../scripts/tuya_control_test.py) for an observed test.
After hidden key entry and a fresh schema/state check, it asks the owner to watch
the bulb before sending commands: on at raw brightness 250, brightness 500,
brightness 750, then off. Each step records API acceptance, bounded cloud
readback, and the owner's physical observation. It attempts to restore the
starting power/brightness even on a command failure or interruption. It requires
white-light mode and leaves color temperature unchanged. It saves a redacted
`docs/research/tuya-control-check.json`; no key is persisted. If restoration
cannot be confirmed, the script tells the owner to restore the state in Smart
Life. Forced termination or lost connectivity can prevent restoration.

The control helper passed offline checks for the command payload, starting-state
guards, cancelled/failed trials, stale readback, and restoration. The owner then
ran it successfully on the physical bulb, including restoration. The agent
inspected the saved results. Its timings include client pacing and are not
Watch or precise physical-response latency measurements.

## External feasibility findings

The Apple Watch interaction is supported by public APIs. Owner-run checks have
confirmed Smart Life phone/cloud control, authenticated REST discovery, and
physical REST power/brightness commands. The remaining integration questions
are direct Watch behavior, sustained command reliability, and usable interactive
latency. No always-on local bridge is available or needed by the validated
desktop cloud path.

### Existing Smart Life Watch app: direct device control unsupported

Smart Life is available for Apple Watch in the Indian App Store. Tuya documents
**Me → Watch**, where compatible devices and tap-to-run scenes can be added;
it also explicitly lists devices that do not support Watch control.
[Smart Life App Store listing](https://apps.apple.com/in/app/smartlife-smart-living/id1115101477?platform=watch),
[Tuya's Watch setup guide](https://developer.tuya.com/en/docs/iot/user-manual-for-tuya-smart-v3177?id=K9obrofrfk4sk).

The owner confirmed that this bulb appears in the unsupported-device list.
Therefore, the built-in direct Watch route cannot provide the requested Crown
interaction in the current setup. Watch tap-to-run scenes might still provide
power or brightness presets if supported; that path is untested and would not
establish continuous Crown dimming. The successful developer API control test
supports building a custom app for the requested interaction.

### New candidate: Tuya End User REST API

Tuya now advertises an End User REST API for building smart-home applications,
with a free API-key entry point. This is a distinct candidate from a traditional
Tuya IoT Core developer project. Tuya's official CLI repository also documents
the end-user API. [Tuya developer entry point](https://www.tuya.ai/developer),
[official CLI](https://github.com/tuya/tuya-smart-control-cli).

Following that entry point to the public login page on 2026-10-08 showed
**Tuya APP** and **SmartLife APP** choices and instructions to select the app
whose devices/data should synchronize. No Wipro choice was displayed. Research
stopped before sign-in or key issuance. The owner subsequently obtained an API
key and completed successful authenticated device/schema reads and observed
power/brightness commands with the local helpers.
[Tuya.AI login](https://auth.tuya.ai/login?loginSource=web_hey_tuya).

The API supports bearer-key authentication, device lists, state, device models,
and property commands. Query the actual model before choosing brightness codes
and ranges; the sample lamp is not evidence for NS9001. The reference labels the
service a trial with rate limits, but does not publish a numeric device-control
quota, trial expiry, or post-trial price. Its explicit server-only restriction
applies to WebSocket subscriptions; the REST section does not state an equivalent
blanket restriction. These public pages do not establish every condition that
may appear during key issuance. [End User API reference](https://www.tuya.ai/developer/docs).

**Assessment:** successful pairing, authenticated discovery, and physical REST
commands support a personal Watch prototype using HTTPS and a user-provided key
stored securely on device. This is an architectural inference, not verified
vendor approval of this exact app. A hosted adapter remains useful for narrower
credentials or server-side events; the proven REST control path does not need
a local bridge. Confirm mobile-use terms, expiry, and quotas before relying on
the app for sustained daily use.

### Traditional Tuya developer project and Wipro account

The prior research's account boundary remains valid. Tuya's **Link My App** flow
requires an app created by the developer; its separate consumer-account linking
flow documents Smart Life and scanning with that app. It does not document an
end user linking an arbitrary Wipro OEM account to a personal cloud project.
[Link Devices](https://developer.tuya.com/en/docs/iot/link-devices?id=Ka471nu1sfmkl).

Tuya's OEM OAuth feature requires enabling the desired app; its release notes
describe authorization by the developer's own OEM-app users. No Wipro-enabled
public OAuth flow was found. Wipro credentials should therefore not be assumed
usable through generic Tuya login or the new API.
[OAuth configuration](https://developer.tuya.com/en/docs/iot/authorization-code-page-usage?id=Kdkyz44dz6a7r),
[Tuya release notes](https://developer.tuya.com/en/docs/iot/announcement-update?id=Ka5o4ytv9ihvq).

For a traditional IoT Core project, the public product page currently lists a
**one-month trial**, 26,000 API calls/month, 68,000 messages/month, and ten
controllable devices. A July 2026 support answer says users can apply for an
extension after the first month; approval and perpetual free renewal are not
guaranteed by that answer. [IoT Core product page](https://www.tuya.com/vas/commodity/IOT_CORE_V2),
[current trial FAQ](https://support.tuya.com/en/help/_detail/Kf4xa2nbp7fp0).

The pricing documentation limits the trial to individual development/debugging,
prohibits commercial use, and suspends service when the allowance is exhausted.
Its 26,000/68,000 figures assume a reference allocation of the basic allowance.
Paid API per-million rates in that table are not a standalone low-cost subscription:
the basic resource pack accompanies an IoT Core edition. The current public
purchase page requires login and did not expose a verifiable entry subscription
price. Do not budget the service from old third-party price claims.
[IoT Core pricing](https://developer.tuya.com/en/docs/iot/membership-service?id=K9m8k45jwvg9j).

Published v2 developer-project property/action command endpoints allow four
requests/second per project. This is not a proven limit for the new End User
API, Home Assistant's SDK, or the physical bulb.
[API frequency limits](https://developer.tuya.com/en/docs/iot/frequency-control?id=Kcojz2r2dg1f6).

For illustration, ten ten-second adjustments per day at two commands/second
produce 6,000 writes in thirty days; a read after each adds another 6,000 calls,
before startup reads, retries, and other usage. At ten writes/second, the same
usage produces 30,000 writes alone. These are workload calculations, not a
measured usage forecast or guaranteed allowance. Coalescing commands and sending
the final value is essential regardless of provider.

### Home Assistant and existing Watch experience

Home Assistant's official Tuya integration accepts devices in Tuya Smart or
Smart Life accounts, supports lights, and is classified **Cloud Push**. Its SDK
may expose fewer features than the consumer app; an empty device schema can
leave only scenes available. It provides no evidence of direct Wipro-account
support or this bulb's compatibility.
[Home Assistant Tuya integration](https://www.home-assistant.io/integrations/tuya/).

Since Home Assistant 2024.2, this integration does **not** require the user to
create a Tuya developer account. Therefore, do not automatically apply the
personal IoT Core trial's expiry and quotas to the current HA integration. It
still depends on Tuya's cloud and an available HA instance.
[Home Assistant 2024.2 release notes](https://www.home-assistant.io/blog/2024/02/07/release-20242/).

The documented HA Watch surface supports scripts, scenes, iOS actions, folders,
and complications. This can provide power and preset-brightness actions if the
bulb integration succeeds. The official Watch documentation does not establish
native continuous Digital Crown dimming, so do not claim it replaces the exact
proposed interaction. Given the user's lack of a bridge, HA is an additional
infrastructure option rather than the first prerequisite.
[HA Apple Watch documentation](https://companion.home-assistant.io/docs/apple-watch/).

### Apple Watch feasibility

SwiftUI exposes Digital Crown bindings with bounded values, sensitivity,
haptics, change callbacks, and an idle callback. This directly supports immediate
local brightness feedback and a final-value command after rotation stops.
[Apple Digital Crown API](https://developer.apple.com/documentation/swiftui/view/digitalcrownrotation(_:from:through:sensitivity:iscontinuous:ishapticfeedbackenabled:onchange:onidle:)).

Foreground HTTPS requests are supported through `URLSession`. Watch apps run
briefly, so lifecycle transitions and unavailable connectivity need explicit
handling. A successful simulator test does not verify real Watch networking.
[Foreground networking](https://developer.apple.com/documentation/watchos-apps/making-default-and-ephemeral-requests).

For an ordinary light-control app, direct TCP/UDP and WebSocket connections on
Watch are outside Apple's supported low-level-networking use cases. HTTP(S)
remains available. This makes a custom Tuya LAN protocol directly on Watch a
poor v1 route, even if the bulb's local protocol can eventually be determined.
[Apple TN3135](https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos).

WatchConnectivity can wake the paired iOS app when the active Watch sends an
immediate message, but the send fails if the counterpart is unreachable. An
independent Watch app cannot use WatchConnectivity as its primary data source.
An iPhone relay is therefore a deliberate phone-dependent fallback, not a fix
for unknown bulb access.
[Apple sendMessage](https://developer.apple.com/documentation/watchconnectivity/wcsession/sendmessage(_:replyhandler:errorhandler:)),
[independent Watch apps](https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps).

### What remains unverified for NS9001

Wipro's current official 9W smart-bulb page advertises app brightness control and
Alexa/Google Assistant. It does not establish this exact NS9001 revision's Smart
Life compatibility, API data points, HomeKit support, or a 10–100% brightness
range. The current Wipro Next App Store listing is iPhone-only. No public Wipro
consumer-control API was found in the reviewed first-party material.
[Wipro 9W smart bulb](https://www.wiproconsumerlighting.com/products/smart-home/smart-home-lights/wipro-9w-wifi-led-smart-bulb),
[Wipro Next listing](https://apps.apple.com/us/app/wipro-next-smart-home/id1437054557).

The owner's [API report](tuya-api-check.json) establishes the raw brightness range
as **10–1000, step 1, scale 0** and identifies `switch_led`, `bright_value`, and
`work_mode`. Raw API units must be mapped deliberately to the Watch percentage;
the original spec's **10–100%** statement was not evidence of the bulb's physical
minimum percentage. Basic API power/brightness control and restoration are now
confirmed. Further tests must establish firmware identity, brightness-only
changes while off, interactive latency, rapid-update behavior, and outage
recovery. API command acceptance,
cached state, fresh device-reported state, and visible lamp response are
different observations; only the last verifies the physical outcome directly.

## Changes to the August research

- Add Tuya End User REST as a newly identified candidate before assuming a
  traditional developer project or a mandatory custom server.
- Make clear that current official HA Tuya setup needs no personal Tuya
  developer account, while remaining cloud-dependent.
- Replace any expectation of indefinitely free direct IoT Core use with a
  trial/renewal/quota check; distinguish its terms from the new API's unknowns.
- Record Smart Life pairing, phone/cloud control, API discovery/schema reads,
  four physical API commands, and restoration as passed for the owner's unit.
- Treat the fixed 10–100% limit and untested NS9001 API/Watch capabilities as
  unverified until supported by device evidence.

## Smallest viable custom implementation

With the basic API experiment passed, test this candidate on Watch next:

```text
iPhone companion: setup and credential provisioning
                         ↓
Apple Watch → HTTPS REST → Tuya End User API → NS9001
```

Use the existing `BulbControlling` boundary. The companion handles setup; the
Watch issues foreground HTTPS commands so routine use need not depend on a
reachable phone. Store a user-supplied key in Keychain, not source code or logs;
Apple supports Keychain storage on Watch. This credential approach is a design
proposal pending the provider's issuance terms, not an assertion that every
mobile use is approved. [Apple Watch data transfer and Keychain](https://developer.apple.com/videos/play/wwdc2021/10003/).

For the first live test, update the displayed value immediately and coalesce
network changes. Start with at most two writes per second **only if the actual
quota permits**, keep one request in flight, and retain only the newest pending
value. Send the final value after rotation stops; ignore obsolete responses.
Use bounded state reads and distinguish requested, accepted, and confirmed
state. Reconcile after app reopening or interruption instead of replaying old
dimming commands. These timings are starting hypotheses, not bulb measurements.

A small hosted adapter is an alternative if credential scope or event delivery
requires a server; it does not require buying home hardware. An iPhone relay is
another option if phone dependence is acceptable, but does not solve unsupported
Wipro access. HA becomes relevant only if the user later adds suitable hosting.

## Decisive validation and stop conditions

These are proposed acceptance targets for this personal project, not vendor
guarantees. The owner has completed pairing, phone/cloud control, API discovery,
and the physical API command/restoration check, and confirmed the unsupported
Watch label. Custom-app outcomes have not yet been tested.

1. **Phone/cloud baseline passed; direct Watch route unsupported.** Keep the
   working Smart Life pairing. Record firmware and available device information
   for the API experiment. Further reset/re-pairing is not the next test. The
   consumer-app results do not prove developer API access.
2. **API discovery and basic physical control passed.** Key issuance,
   authentication, India data center, online visibility, and writable power/
   brightness schema are confirmed. The observed helper's four commands and
   restoration all passed API acceptance, state readback, and physical
   observation. Record white/color-mode behavior separately. Establish trial
   duration, quota and ongoing access before treating this as a daily-use dependency.
3. **Interaction trial.** Try 20 short dimming gestures with varied final values
   and 10 power commands. Aim for 20/20 correct final values within two seconds
   of stopping, no later rollback, and 10/10 correct power outcomes under normal
   connectivity. Record API acceptance, state confirmation, and visible response
   separately, including median and worst delay. If “dim while turning” matters,
   also measure intermediate visible response; final delivery alone is not enough.
4. **Recovery and phone independence.** Test bulb/network interruption, Watch app
   backgrounding, and reopening. Show failure or pending status rather than false
   success; recover to current state when connectivity returns. Test with the
   iPhone unreachable while the Watch has its own internet connection. A small
   passing sample justifies a prototype, not a reliability guarantee.

Proceed with the small Watch prototype now that basic API control has passed.
Daily-use readiness still requires acceptable Watch latency, recovery behavior,
and sustainable access terms. If access is later withdrawn or becomes unsuitable,
reassess the integration before further investment. If only latency fails,
presets or final-value-only dimming are possible scope changes; they do not
satisfy continuous Crown control by themselves.

## Effort and operating costs

Estimates below are engineering judgments for one developer comfortable with
SwiftUI and HTTP APIs, with existing Mac/iPhone/Watch/bulb hardware. They exclude
waiting for provider approval and any unsupported protocol investigation.

| Work | Rough effort |
| --- | --- |
| Pairing, existing-app check, and API feasibility spike | Half a day to one day if setup succeeds |
| Simulated single-screen Watch interaction | 1–2 development days |
| Live adapter, companion setup, signing, failure handling and device checks | Another 2–5 development days after API proof |

A usable personal MVP is therefore plausibly **3–7 development days after the
integration proof**, with extra time if watchOS/signing is unfamiliar. The basic
integration proof has now passed. This remains a rough estimate, conditional on
Watch compatibility, signing, provider terms, and physical interaction results.

Apple permits free personal on-device testing, but Personal Team provisioning
expires after seven days and can require rebuilding/reinstalling. The paid
Developer Program is US$99 per year or the offered regional price; membership
is not required merely to begin the prototype.
[Apple account limits](https://developer.apple.com/help/account/basics/about-your-developer-account),
[membership pricing](https://developer.apple.com/help/account/membership/program-enrollment).

The direct REST candidate adds no local bridge purchase. Its API is advertised
with free entry, but a zero-cost, permanent service is not established. Hosted
adapter costs, if needed, depend on the selected service; none has been selected
or priced here. For one bulb, ongoing API, signing and infrastructure effort may
matter more than implementation size. Build when the Crown interaction or the
learning value justifies that effort.
