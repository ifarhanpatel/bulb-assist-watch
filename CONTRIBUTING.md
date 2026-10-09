# Contributing

Start with the credential-free [setup](docs/setup.md). Use `make test` and
`make build` for ordinary changes, plus the relevant native tests for platform
storage, provisioning or UI changes. Run simulator sessions sequentially.
Python helpers must never run against a live key in CI.

## Structure and scope

- `Packages/BulbCore`: Swift domain state, scheduling, provisioning and Tuya REST adapters.
- `Apps/Shared`: Keychain, native transport and WatchConnectivity integration.
- `Apps/iPhone` / `Apps/Watch`: companion setup and Crown/control views.
- `Tests`: native platform and UI tests; core tests live inside the package.
- `project.yml`: XcodeGen source for the checked-in Xcode project.
- `docs/specs`: product/technical constraints; `docs/validation` separates simulation from hardware evidence.

Keep changes focused. Update the relevant spec when behavior changes, add tests
for substantive behavior, and describe what was verified and what remains
unverified in the pull request. Run `make generate` after source membership or
project settings change. Keep your team, bundle namespace and credentials out
of tracked settings. No external Swift dependencies are currently required;
explain any proposed dependency and its license before adding it.

Preserve the control guarantees: validate capabilities before writes, never
replay an uncertain write blindly, respect cooldown, discard unsent intent on
backgrounding, and acknowledge durable provisioning changes. Add a candidate
model with fixtures and conservative validation rather than widening the
[compatibility claim](docs/compatibility.md) based on branding alone.

## Safe reports

Use the bug or compatibility template. Include simulator/OS versions, model and
firmware where relevant, steps, expected/actual behavior, and sanitized error
categories. Never include a real key, device ID, account/home name, raw response,
provisioning payload, signing certificate, or unreviewed screenshot/log.
Use [SECURITY.md](SECURITY.md) for a suspected exposure.

Design exports are illustrative; native screenshots record specific validation
runs. Do not present one as the other. New assets need clear provenance and any
required notice in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Contributions must be yours to submit. Unless explicitly stated otherwise and
agreed before inclusion, contributions use the repository's MIT license; retain
third-party notices. A service's terms do not become extra restrictions in MIT.

Run `python3 scripts/export-source.py` to prepare the reviewed publication
layout. The [release procedure](docs/release.md) explains scanning and the fresh
history requirement for the initial public release.
