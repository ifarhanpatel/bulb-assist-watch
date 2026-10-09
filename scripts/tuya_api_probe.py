#!/usr/bin/env python3
"""Read-only Tuya feasibility probe; key arrives on stdin and is never saved.

API contract: https://www.tuya.ai/developer/docs
Run through check-tuya-api.sh for hidden key entry and interactive selection.
"""

import json
import os
from pathlib import Path
import re
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import HTTPRedirectHandler, Request, build_opener


HOSTS = {
    "AY": "openapi.tuyacn.com",
    "AZ": "openapi.tuyaus.com",
    "EU": "openapi.tuyaeu.com",
    "IN": "openapi.tuyain.com",
    "UE": "openapi-ueaz.tuyaus.com",
    "WE": "openapi-weaz.tuyaeu.com",
    "SG": "openapi-sg.iotbing.com",
}


class ProbeError(Exception):
    """A safe, locally authored error; never include raw API responses."""


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward a bearer key to a redirect target.
        return None


def region_for(key):
    region = key[3:5] if key.startswith("sk-") else ""
    if (region not in HOSTS or len(key) <= 5 or len(key) > 4096
            or not key.isascii() or any(c.isspace() or ord(c) < 32 for c in key)):
        raise ProbeError("Key format not recognized. Use the Tuya End User API key.")
    return region


def safe_code(value):
    value = str(value)
    return value if re.fullmatch(r"[0-9]{1,12}", value) else "unreported"


def decode_object(value):
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except (ValueError, TypeError):
            return {}
    return value if isinstance(value, dict) else {}


class TuyaReader:
    def __init__(self, key):
        self.key = key
        self.region = region_for(key)
        self.host = HOSTS[self.region]
        self.opener = build_opener(NoRedirects())
        self.last_request = None

    def get(self, path):
        if not path.startswith("/v1.0/end-user/devices/"):
            raise ProbeError("Only device-discovery GET paths are allowed.")
        request = Request(
            "https://" + self.host + path,
            headers={"Authorization": "Bearer " + self.key, "Accept": "application/json"},
            method="GET",
        )
        return self._send(request)

    def _send(self, request):
        if self.last_request is not None:
            time.sleep(max(0, 1 - (time.monotonic() - self.last_request)))
        self.last_request = time.monotonic()
        try:
            with self.opener.open(request, timeout=20) as response:
                raw = response.read(2_000_001)
        except HTTPError as error:
            raise ProbeError("API returned HTTP " + str(error.code) + ".") from None
        except (URLError, TimeoutError, OSError):
            raise ProbeError("Connection failed or timed out; check internet and retry.") from None
        if len(raw) > 2_000_000:
            raise ProbeError("API response exceeded the probe's size limit.")
        try:
            payload = json.loads(raw)
        except (ValueError, UnicodeError):
            raise ProbeError("API returned a non-JSON response.") from None
        if not isinstance(payload, dict) or payload.get("success") is not True:
            code = safe_code(payload.get("code")) if isinstance(payload, dict) else "unreported"
            raise ProbeError("API rejected the request; error code " + code + ".")
        return payload.get("result")


def property_summary(model_result, detail):
    model = decode_object(model_result)
    model = decode_object(model.get("model", model))
    services = model.get("services", [])
    states = detail.get("properties", {})
    states = states if isinstance(states, dict) else {}
    properties = []
    for service in services if isinstance(services, list) else []:
        if not isinstance(service, dict):
            continue
        entries = service.get("properties", [])
        for prop in entries if isinstance(entries, list) else []:
            if not isinstance(prop, dict):
                continue
            code = prop.get("code")
            if not isinstance(code, str):
                continue
            spec = decode_object(prop.get("typeSpec"))
            entry = {"code": code, "access": prop.get("accessMode"), "type": spec.get("type")}
            for field in ("min", "max", "step", "scale", "unit", "range"):
                if field in spec:
                    entry[field] = spec[field]
            # Omit string/raw payload states; report only simple control values.
            state = states.get(code)
            if type(state) in (bool, int, float) or (
                spec.get("type") == "enum" and isinstance(state, str)
            ):
                entry["reported_state"] = state
            properties.append(entry)
    return properties


def choose_device(devices, key):
    if not devices:
        raise ProbeError("No devices returned. Check that the key is linked to your Smart Life account.")
    print("Devices visible to the API (IDs omitted):")
    for number, device in enumerate(devices, 1):
        # JSON quoting prevents control sequences in device names affecting the terminal.
        name = str(device.get("name", "Unnamed device")).replace(key, "[redacted]")
        print("  {}. {}".format(number, json.dumps(name, ensure_ascii=True)))
    if len(devices) == 1:
        return devices[0]
    with open("/dev/tty", "r") as terminal_in, open("/dev/tty", "w") as terminal_out:
        while True:
            terminal_out.write("Select the Wipro bulb's number: ")
            terminal_out.flush()
            value = terminal_in.readline()
            if not value:
                raise ProbeError("No selection received.")
            try:
                number = int(value.strip())
            except ValueError:
                continue
            if 1 <= number <= len(devices):
                return devices[number - 1]


def write_report(path, report, secrets):
    data = json.dumps(report, indent=2, ensure_ascii=True)
    for secret in secrets:
        if secret:
            # Replace JSON-escaped variants too, if a response unexpectedly echoes a value.
            data = data.replace(json.dumps(secret, ensure_ascii=True)[1:-1], "[redacted]")
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".tuya-probe-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            output.write(data + "\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print("\n" + data)
    print("\nReport saved to: " + str(path))


def main(report_path):
    key = sys.stdin.readline(8192).strip()
    report = {"checked_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
              "read_only": True, "device_ids_omitted": True, "checks": {}}
    secrets = [key]
    status = 0
    try:
        reader = TuyaReader(key)
        report["data_center"] = reader.region
        result = reader.get("/v1.0/end-user/devices/all")
        devices = result.get("devices") if isinstance(result, dict) else None
        if not isinstance(devices, list) or any(not isinstance(d, dict) for d in devices):
            raise ProbeError("Unexpected device-list format; no raw account data was saved.")
        report["checks"]["authentication"] = "passed"
        report["device_count"] = len(devices)
        secrets.extend(str(d["device_id"]) for d in devices if d.get("device_id"))
        device = choose_device(devices, key)
        device_id = device.get("device_id")
        if not isinstance(device_id, str) or not device_id:
            raise ProbeError("Selected device has no usable device ID.")
        report["checks"]["device_visible"] = "passed"
        base = "/v1.0/end-user/devices/" + quote(device_id, safe="")
        detail = reader.get(base + "/detail")
        if not isinstance(detail, dict):
            raise ProbeError("Device detail is unavailable for this key.")
        report["online"] = detail.get("online")
        model = reader.get(base + "/model")
        props = property_summary(model, detail)
        report["properties"] = props
        report["checks"]["model"] = "parsed" if props else "no properties parsed; needs investigation"
        writable = [p for p in props if p["access"] in ("rw", "wr")]
        report["power_candidates"] = [p["code"] for p in writable
                                      if p["type"] == "bool" and p["code"] in ("switch_led", "switch", "switch_1")]
        report["brightness_candidates"] = [p["code"] for p in writable
                                           if p["type"] == "value" and "bright" in p["code"]]
        report["next_step"] = "Review capabilities before a physical power/brightness command test."
    except ProbeError as error:
        report["error"] = str(error)
        status = 1
    except (KeyboardInterrupt, EOFError):
        report["error"] = "Check cancelled; key was not saved."
        status = 1
    write_report(report_path, report, secrets)
    return status


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Run check-tuya-api.sh to enter your key privately.", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(Path(sys.argv[1]).resolve()))
