#!/usr/bin/env bash

# torrent-finished.sh "%I" "%N"

INFO_HASH="${1}" # %I
TORRENT_NAME="${2}" # %N

status_code="$(
    curl \
        --silent \
        --output /dev/null \
        --write-out "%{http_code}" \
        --request POST \
        --data-urlencode "infoHash=${INFO_HASH}" \
        --header "X-Api-Key: ${CROSS_SEED_API_KEY}" \
       http://cross-seed.media.svc.cluster.local/api/webhook 
)"

echo "$(date) - cross-seed - ${status_code} - ${TORRENT_NAME}"
