#!/usr/bin/env bash

set -euo pipefail

NTFY_TOKEN="${1}"
PAYLOAD="${2}"

echo "[DEBUG] Payload: ${PAYLOAD}"

event="$(jq -r '.event' <<< "${PAYLOAD}")"
subject="$(jq -r '.subject' <<< "${PAYLOAD}")"
message="$(jq -r '.message' <<< "${PAYLOAD}")"

body="$(
cat << EOF
${subject}
${message}
EOF
)"

curl -s \
    -H "Title: ${event}" \
    -H "Tags: duck, eye" \
    -d "${body}" \
    "https://ntfy.sh/mallard-overseerr-${NTFY_TOKEN}"
