#!/usr/bin/env python3
"""Observed NS9001 API smoke test; run with test-tuya-control.sh.

Sends documented property commands: https://www.tuya.ai/developer/docs
Key is read from stdin, kept in memory, and redacted from the saved report.
"""

import json
from pathlib import Path
import sys
import time
from urllib.parse import quote
from urllib.request import Request

from tuya_api_probe import ProbeError, TuyaReader, choose_device, property_summary, write_report


class TuyaControl(TuyaReader):
    def issue(self, device_id, properties):
        # The narrow smoke test never sends unknown controls or arbitrary payloads.
        if not properties or set(properties) - {"switch_led", "bright_value"}:
            raise ProbeError("Only power and brightness commands are allowed.")
        if "switch_led" in properties and type(properties["switch_led"]) is not bool:
            raise ProbeError("Power must be a boolean.")
        if "bright_value" in properties and (
            type(properties["bright_value"]) is not int or not 10 <= properties["bright_value"] <= 1000
        ):
            raise ProbeError("Brightness must be an integer in the verified 10–1000 range.")
        path = "/v1.0/end-user/devices/" + quote(device_id, safe="") + "/shadow/properties/issue"
        body = json.dumps({"properties": json.dumps(properties)}).encode()
        request = Request(
            "https://" + self.host + path,
            data=body,
            headers={"Authorization": "Bearer " + self.key,
                     "Content-Type": "application/json", "Accept": "application/json"},
            method="POST",
        )
        return self._send(request)


def ask_observer(prompt, allow_quit=True):
    choices = "[y/n/q]" if allow_quit else "[y/n]"
    with open("/dev/tty", "r") as terminal_in, open("/dev/tty", "w") as terminal_out:
        while True:
            terminal_out.write(prompt + " " + choices + ": ")
            terminal_out.flush()
            answer = terminal_in.readline()
            if not answer:
                raise EOFError
            answer = answer.strip().lower()
            if answer in ("y", "yes", "n", "no"):
                return answer in ("y", "yes")
            if allow_quit and answer == "q":
                raise KeyboardInterrupt


def snapshot(detail, model):
    if not isinstance(detail, dict) or detail.get("online") is not True:
        raise ProbeError("The bulb must be online before the control test.")
    controls = {p["code"]: p for p in property_summary(model, detail)}
    power = controls.get("switch_led", {})
    brightness = controls.get("bright_value", {})
    if power.get("access") != "rw" or power.get("type") != "bool":
        raise ProbeError("Writable power schema differs from the verified bulb.")
    if (brightness.get("access") != "rw" or brightness.get("type") != "value"
            or (brightness.get("min"), brightness.get("max"), brightness.get("step")) != (10, 1000, 1)):
        raise ProbeError("Brightness schema differs from the verified 10–1000 range.")
    states = detail.get("properties", {})
    if not isinstance(states, dict) or states.get("work_mode") != "white":
        raise ProbeError("Select white-light mode in Smart Life, then rerun the test.")
    power_value, brightness_value = states.get("switch_led"), states.get("bright_value")
    if type(power_value) is not bool or type(brightness_value) is not int or not 10 <= brightness_value <= 1000:
        raise ProbeError("Starting power/brightness state is unavailable; no commands sent.")
    return {"switch_led": power_value, "bright_value": brightness_value}


def readback(client, base, expected):
    for _ in range(3):
        detail = client.get(base + "/detail")
        state = detail.get("properties", {}) if isinstance(detail, dict) else {}
        if (isinstance(state, dict) and detail.get("online") is True
                and all(state.get(code) == value for code, value in expected.items())):
            return True
    return False


def run_trial(client, device_id, initial, report, observe=ask_observer):
    base = "/v1.0/end-user/devices/" + quote(device_id, safe="")
    sequence = [
        ("on at 25% of maximum command value", {"switch_led": True, "bright_value": 250}),
        ("brightness at 50% of maximum command value", {"bright_value": 500}),
        ("brightness at 75% of maximum command value", {"bright_value": 750}),
        ("off", {"switch_led": False}),
    ]
    print("\nThe bulb will turn on, use brightness values 250, 500, 750, then turn off.")
    print("Each step waits for your observation. The starting power and brightness will be restored afterward.")
    print("Keep Smart Life and other controls idle during this test. Enter q to stop and attempt restoration.")
    if not observe("Are you watching the bulb and ready to start?"):
        report["outcome"] = "not started"
        return
    attempted = False
    report["steps"] = []
    try:
        for label, command in sequence:
            step = {"expected": command, "api_accepted": False}
            report["steps"].append(step)
            attempted = True
            started = time.monotonic()
            client.issue(device_id, command)
            step["api_accepted"] = True
            step["command_elapsed_seconds_including_pacing"] = round(time.monotonic() - started, 3)
            print("\nRequested: " + label)
            step["reported_state_matches"] = readback(client, base, command)
            print("Cloud readback matches: " + str(step["reported_state_matches"]))
            step["physically_observed"] = observe("Did the lamp visibly reach the requested state?")
            if not step["physically_observed"] or not step["reported_state_matches"]:
                report["outcome"] = "observation or state mismatch; stopped"
                break
        else:
            report["outcome"] = "all four commands accepted, read back, and physically observed"
    finally:
        if attempted:
            restoration = {"attempted": True, "api_accepted": False}
            report["restoration"] = restoration
            try:
                print("\nRestoring the starting power and brightness...")
                client.issue(device_id, initial)
                if initial["switch_led"] is False:
                    # Some lamps power on when brightness changes; make off the final command.
                    client.issue(device_id, {"switch_led": False})
                restoration["api_accepted"] = True
                restoration["reported_state_matches"] = readback(client, base, initial)
                restoration["physically_observed"] = observe("Is the lamp back to its starting state?")
            except (ProbeError, KeyboardInterrupt, EOFError):
                restoration["error"] = "Restoration could not be confirmed. Restore the bulb in Smart Life."
            if not restoration.get("reported_state_matches") or not restoration.get("physically_observed"):
                print("Restoration was not confirmed. Use Smart Life to restore your preferred state.")


def main(report_path):
    key = sys.stdin.readline(8192).strip()
    report = {"checked_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
              "read_only": False, "device_ids_omitted": True,
              "purpose": "Observed API power/brightness smoke test; no Watch latency claim"}
    secrets = [key]
    status = 0
    try:
        client = TuyaControl(key)
        report["data_center"] = client.region
        result = client.get("/v1.0/end-user/devices/all")
        devices = result.get("devices") if isinstance(result, dict) else None
        if not isinstance(devices, list) or any(not isinstance(d, dict) for d in devices):
            raise ProbeError("Unexpected device-list response.")
        secrets.extend(str(d["device_id"]) for d in devices if d.get("device_id"))
        device = choose_device(devices, key)
        device_id = device.get("device_id")
        if not isinstance(device_id, str) or not device_id:
            raise ProbeError("Selected device has no usable ID.")
        base = "/v1.0/end-user/devices/" + quote(device_id, safe="")
        detail = client.get(base + "/detail")
        model = client.get(base + "/model")
        initial = snapshot(detail, model)
        report["initial_state"] = initial
        run_trial(client, device_id, initial, report)
        if report.get("outcome") != "all four commands accepted, read back, and physically observed":
            status = 1
        restoration = report.get("restoration", {})
        if not restoration.get("reported_state_matches") or not restoration.get("physically_observed"):
            status = 1
    except ProbeError as error:
        report["error"] = str(error)
        status = 1
    except (KeyboardInterrupt, EOFError):
        report["error"] = "Test cancelled; inspect the restoration result."
        status = 1
    write_report(report_path, report, secrets)
    return status


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Run test-tuya-control.sh to enter your key privately.", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(Path(sys.argv[1]).resolve()))
