# Direct Watch control with companion setup

Status: accepted for the personal prototype, 2026-10-08.

Desktop experiments proved Tuya End User HTTPS control of the owner's NS9001,
while Smart Life's built-in Watch app reports this bulb as unsupported. The
prototype will use direct foreground Watch REST requests with iPhone setup and
device-local Keychain provisioning. Compared with a phone relay, this permits
routine control when the phone is unreachable; compared with a hosted adapter,
it avoids additional hosting while accepting broader on-device credentials and
cloud dependence. Provider mobile-use terms, durable access, Watch networking,
latency, and credential transfer remain validation gates before daily use.

The Watch interaction uses the `BulbControlling` interface in a shared Swift
package. M1 implements only the simulated adapter and local interaction; M2 adds
paced command scheduling and bounded recovery, and M3 adds the real adapter and
credential provisioning. A simulated result is never evidence of physical control.
