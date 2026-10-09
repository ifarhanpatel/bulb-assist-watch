# Privacy

Bulb Assist is an independent app you build and run. It has no project-operated
backend, analytics SDK, advertising or telemetry endpoint in the reviewed source.
**Live control depends on Tuya's cloud.** This document describes the code's data
handling; it does not control Tuya's policies or Apple operating-system diagnostics.

## Data flow and storage

| Data | Where it goes | Why |
| --- | --- | --- |
| Your End User API key | Entered on iPhone; device-local Keychain on iPhone and Watch; HTTPS bearer authentication to Tuya | Discovery and authorized control |
| Selected bulb ID, name, region and revision | Local configuration and active paired WatchConnectivity messages | Select the target and apply the latest configuration |
| Device list/model/state | Tuya responses to iPhone setup or direct Watch requests | Validate compatibility and display state |
| Power/brightness commands and timing | Regional Tuya HTTPS endpoint, together with the target ID | Operate the bulb and read back its state |

A selected bulb does not narrow the provider key's permissions. A compromised
key may expose every device or function that Tuya grants it. Tuya also receives
normal connection metadata such as source IP and request times. Refer to the
policies linked from the [official API documentation](https://www.tuya.ai/developer/docs)
and the agreement for your account for provider retention and rights.

Both Keychain stores are non-synchronizing and use
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. The app uses active paired
WatchConnectivity messages with storage acknowledgements; it does not queue keys
in background application-context/user-info transfers. Keys are also held in
process memory while needed. Secure text entry masks the field but does not
protect a compromised device or a screen recording made elsewhere in setup.

The native transport uses ephemeral URLSession storage, disables cookies/cache,
and rejects redirects. Routine control is direct Watch-to-Tuya HTTPS; the phone
is not a relay. The app does not send credentials to the project maintainer.

## Removal and revocation

Removal deletes the local credential payload and retains a revision tombstone
so stale provisioning cannot restore it. The Watch must acknowledge removal;
until then it may retain the prior credential. Replacement similarly requires
acknowledgement. Neither action revokes a key at Tuya or deletes provider records.
Use Tuya's key management to revoke access. Do not assume app uninstall clears
Keychain data; do not use uninstall as a substitute for removal and revocation.

## Diagnostics and contributions

Debug Measurements contains in-memory request counters and readback timing;
resetting it is observational. The reviewed native code does not log keys or raw
API bodies. Xcode, the OS, crash reporting you enable, or your own modifications
can produce additional diagnostics: inspect anything you share.

Optional Python helpers read keys from standard input and keep them in memory.
Their saved reports omit keys and device IDs, but include region, timestamps,
property metadata and simple state. Terminal selection can display device names.
Reports default to ignored `build/reports/`; avoid terminal recordings and review
all output before publishing. Historical reports in the docs were individually
reviewed and intentionally retain nonsensitive validation context.

Tests and prototypes use synthetic credentials and fake transports. Never put a
live key, account dump, device identifier or home/location name in an issue, test
fixture, screenshot or pull request. See [SECURITY.md](SECURITY.md) for reporting.

The [release privacy audit](docs/research/open-source-privacy-review.md) records
source/history/image coverage and its limits. It is a source review with selected
platform tests, not an independent penetration test or a full network-capture audit.
