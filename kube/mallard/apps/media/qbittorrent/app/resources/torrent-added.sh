#!/usr/bin/env bash

# torrent-added.sh "%I" "%N"

INFO_HASH="${1}" # %I
TORRENT_NAME="${2}" # %N

status_code="$(
    curl \
       --silent \
       --output /dev/null \
       --write-out "%{http_code}" \
       --request POST \
       --data-urlencode "infoHash=${INFO_HASH}" \
       http://qbtagarr.media.svc.cluster.local:8080/api/webhook 
)"

echo "$(date) - qbtagarr - ${status_code} - ${TORRENT_NAME}"
