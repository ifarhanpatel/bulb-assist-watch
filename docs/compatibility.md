# Bulb compatibility

“Tuya compatible” is not a sufficient guarantee. Bulb Assist uses the documented
Tuya **End User cloud REST API**, not local Wi-Fi discovery, LAN keys, Bluetooth,
Zigbee or Matter control. A bulb must be visible to your linked account and its
model must pass the validator before setup/control proceeds.

## Required model

| Property code | Type | Access | Required schema |
| --- | --- | --- | --- |
| `switch_led` | `bool` | `rw` | Boolean power |
| `bright_value` | `value` | `rw` | min `10`, max `1000`, step `1`, scale `0` |
| `work_mode` | `enum` | `ro` or `rw` | Unique, nonempty values including `white` |

Property codes must be unique across model services. Alternate names such as
`bright_value_v2`, a 0–255 range, or missing access/type metadata are unsupported;
the app does not guess or remap them. See the
[validator](../Packages/BulbCore/Sources/BulbCore/Tuya/TuyaDiscovery.swift).

The UI selects 10–100% brightness. A lower value reported by the bulb is
preserved until the user changes it; support for raw 10–1000 values does not
mean the UI offers the entire raw range. Brightness writes require current
`work_mode` to be `white`. Power remains available in another recognized mode.
The app never switches modes or writes color/temperature properties.

## Evidence

| Device | Status | Scope |
| --- | --- | --- |
| Wipro NS9001 | Owner-confirmed physical operation with one sample | Setup, relaunch, state reads, power, white brightness, replacement/removal and reprovisioning; see [integration record](validation/parallel/native-integration.md) |
| Other Tuya Wi-Fi bulbs matching the schema | Expected candidates; not physically validated here | Account visibility, model parsing, firmware behavior and readback still need verification |
| Other property schemas, multi-bulb control, local/offline control | Unsupported | Needs implementation and separate validation |

An observed model is not a claim about every unit or firmware revision sold
under that name. Sustained use, timing and quota checks remain in the
[M4 hardware run sheet](validation/m4/hardware-run.md).

To report a candidate, provide the manufacturer/model, firmware version if
available, and only the three schema rows above plus sanitized observed behavior.
Do not attach a raw API response, key, device ID, account identity or home/location
name. Use the compatibility issue template and [contribution guidance](../CONTRIBUTING.md).
