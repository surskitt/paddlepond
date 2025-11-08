#!/bin/sh 

PORTS="${1}"

echo "Forwarding port ${1}"

wget -O- \
    --retry-connrefused \
    --post-data \
    "json={\"listen_port\":${1}}" \
    http://127.0.0.1:8080/api/v2/app/setPreferences 2>&1
