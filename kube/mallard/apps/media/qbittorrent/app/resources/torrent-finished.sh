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

if "${NEMOROSA_ENABLE:-true}" ; then
    status_code="$(
        curl \
            --silent \
            --output /dev/null \
            --write-out "%{http_code}" \
            --request POST \
            --header "Authorization: Bearer ${NEMOROSA_API_KEY}" \
           "http://nemorosa.media.svc.cluster.local:8256/api/webhook?infohash=${INFO_HASH}"
    )"

    echo "$(date) - nemorosa - ${status_code} - ${TORRENT_NAME}"
fi
