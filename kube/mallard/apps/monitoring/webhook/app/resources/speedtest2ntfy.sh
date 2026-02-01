#!/usr/bin/env bash

set -euo pipefail

NTFY_TOKEN="${1}"
PAYLOAD="${2}"

echo "[DEBUG] Payload: ${PAYLOAD}"

event="Speedtest Threshold Breached"

isp="$(jq -r '.isp' <<< "${PAYLOAD}")"
download_passed="$(jq -r '.benchmarks.download.passed' <<< "${PAYLOAD}")"
download_value="$(jq -r '.benchmarks.download.value' <<< "${PAYLOAD}")"
download_unit="$(jq -r '.benchmarks.download.unit' <<< "${PAYLOAD}")"
upload_passed="$(jq -r '.benchmarks.upload.passed' <<< "${PAYLOAD}")"
upload_value="$(jq -r '.benchmarks.upload.value' <<< "${PAYLOAD}")"
upload_unit="$(jq -r '.benchmarks.upload.unit' <<< "${PAYLOAD}")"
ping_passed="$(jq -r '.benchmarks.ping.passed' <<< "${PAYLOAD}")"
ping_value="$(jq -r '.benchmarks.ping.value' <<< "${PAYLOAD}")"
ping_unit="$(jq -r '.benchmarks.ping.unit' <<< "${PAYLOAD}")"
speedtest_url="$(jq -r '.speedtest_url' <<< "${PAYLOAD}")"
url="$(jq -r '.url' <<< "${PAYLOAD}")"

if "${download_passed}" ; then
    download_status="passed"
else
    download_status="failed"
fi

if "${upload_passed}" ; then
    upload_status="passed"
else
    upload_status="failed"
fi

if "${ping_passed}" ; then
    ping_status="passed"
else
    ping_status="failed"
fi

body="$(
cat << EOF
A speedtest was run on ${isp} but a threshold was breached.

Download (${download_status}): ${download_value} ${download_unit}
Upload (${upload_status}): ${upload_value} ${upload_unit}
Ping (${ping_status}): ${ping_value} ${ping_unit}

URL: ${url}
Speedtest: ${speedtest_url}
EOF
)"

curl -s \
    -H "Title: ${event}" \
    -H "Tags: duck, running_man" \
    -d "${body}" \
    "https://ntfy.sh/mallard-speedtest-tracker-${NTFY_TOKEN}"
