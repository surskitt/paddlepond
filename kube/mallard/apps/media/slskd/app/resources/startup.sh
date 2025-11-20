#!/usr/bin/env bash

eth0_ip="$(hostname -i)"
wg0_ip="$(for i in $(hostname -I) ; do if [[ "${i}" != "${eth0_ip}" ]] ; then echo "${i}" ; fi ; done)"

echo "Exporting listen ip: ${wg0_ip}"

export SLSKD_SLSK_LISTEN_IP_ADDRESS="${wg0_ip}"

listen_port="$(wget -q -O- "http://localhost:8000/v1/openvpn/portforwarded" | jq -r '.port')"

echo "Exposting listen port: ${listen_port}"

export SLSKD_SLSK_LISTEN_PORT="${listen_port}"

exec /slskd/start.sh
