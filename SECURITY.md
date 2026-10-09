# Security reporting

This is experimental software. There is no support SLA, security certification,
or guarantee of immediate fixes. Security fixes target the current source branch.

**Do not post credentials, device IDs, raw API responses, provisioning payloads,
or private diagnostics in public issues.** If a real key is exposed, revoke it
through Tuya before relying on deletion from a file, issue, or Git history.

Use the repository's **Security → Report a vulnerability** button when it is
available. Private vulnerability reporting is enabled for this repository.

If the button is absent, open an issue containing only “Please provide a private
security reporting channel.” Wait for an agreed private channel before sending
the report. There is no published security email address at present. This fallback
must not contain vulnerability details or personal data.

A useful private report describes the affected version, safe reproduction steps,
expected/observed behavior and impact. Use synthetic values. Do not test against
other people's accounts or devices. See [PRIVACY.md](PRIVACY.md) for credential
handling and the distinction between local removal and provider revocation.
