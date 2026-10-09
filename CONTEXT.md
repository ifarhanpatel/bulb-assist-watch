# Bulb Assist

A personal remote for one smart bulb. Its language distinguishes the user's
selection from the state reported by the bulb-control service.

## Language

**Brightness selection**:
The brightness chosen by the user for the next change. It can exist while the bulb
is off without changing the bulb.
_Avoid_: Actual brightness, current bulb state

**Reported brightness**:
The brightness most recently returned by the bulb-control service. It can differ
from the user's selection or the visible light output.
_Avoid_: Physically confirmed brightness

**Accepted command**:
A change acknowledged by the bulb-control service. Acceptance alone does not
establish matching reported state or a visible response.
_Avoid_: Successful bulb change

**Reported confirmation**:
A state read that matches the requested change. Physical observation is a separate
check of the visible lamp response.

**Local selection while off**:
A brightness selection for the next power-on. The bulb remains off until the user
taps the on-screen power button.

**Power button**:
The on-screen Turn on or Turn off control in Bulb Assist.
_Avoid_: Watch side button
