#!/usr/bin/env bash
# Bulb Assist: interactive local diagnostics. Never run with a real key in CI.
set -euo pipefail
set +x
set +v

if [[ ! -t 0 || ! -t 1 ]]; then
  printf 'Run this script yourself in an interactive terminal.\n' >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf 'Python 3 is required.\n' >&2
  exit 1
fi

BULB_ASSIST_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BULB_ASSIST_REPORT="${BULB_ASSIST_SCRIPT_DIR}/../build/reports/tuya-control-check.json"
trap 'unset BULB_ASSIST_API_KEY' EXIT
printf 'This test changes brightness and power after interactive confirmation.\nSupervise the lamp, select white mode in Smart Life, and check restoration.\n'
printf 'Your key stays in memory. Device names may appear during selection.\n'
printf 'Enter your existing Tuya End User API key (hidden): '
IFS= read -r -s BULB_ASSIST_API_KEY
printf '\n'
if [[ -z "$BULB_ASSIST_API_KEY" ]]; then
  printf 'No key entered. Nothing was sent.\n' >&2
  exit 1
fi

if printf '%s\n' "$BULB_ASSIST_API_KEY" | python3 -B "${BULB_ASSIST_SCRIPT_DIR}/tuya_control_test.py" "$BULB_ASSIST_REPORT"; then
  unset BULB_ASSIST_API_KEY
  printf 'Control test and restoration confirmed.\n'
  printf 'Review reports locally before sharing. Output stays in ignored build/reports/.\n'
else
  unset BULB_ASSIST_API_KEY
  printf 'The check did not complete. Review the report; never share a raw device dump.\n' >&2
  printf 'For a control test, check the lamp and restore it in Smart Life if needed.\n' >&2
  exit 1
fi
