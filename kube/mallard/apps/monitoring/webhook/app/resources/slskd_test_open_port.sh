#!/usr/bin/env bash

set -euo pipefail

public_ip="$(curl -L -s http://slskd.media.svc.cluster.local:8000/v1/publicip/ip | jq -r .public_ip)"
listen_port="$(curl -L -s http://slskd.media.svc.cluster.local:8000/v1/openvpn/portforwarded | jq .port)"

nc -w 5 -vz "${public_ip}" "${listen_port}"
