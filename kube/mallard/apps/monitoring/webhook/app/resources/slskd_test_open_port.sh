#!/usr/bin/env bash

set -euo pipefail

GLUETUN_API_KEY="${1}"

public_ip="$(curl -H "X-API-Key: ${GLUETUN_API_KEY}" -L -s "http://slskd.media.svc.cluster.local:8000/v1/publicip/ip" | jq -r .public_ip)"
listen_port="$(curl -H "X-API-Key: ${GLUETUN_API_KEY}" -L -s "http://slskd.media.svc.cluster.local:8000/v1/portforward" | jq .port)"

nc -w 5 -vz "${public_ip}" "${listen_port}"
