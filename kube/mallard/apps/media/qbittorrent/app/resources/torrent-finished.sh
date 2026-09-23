#!/usr/bin/env bash

# torrent-finished.sh "%I" "%N"

INFO_HASH="${1}"    # %I
TORRENT_NAME="${2}" # %N
CATEGORY="${3}"     # %L
TAGS="${4}"         # %G
CONTENT_PATH="${5}" # %F

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

if "${NEMOROSA_ENABLE:-true}"; then
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

if [[ "${CATEGORY}" == "music/unsorted" ]] && [[ "${TAGS}" == *"auto"* ]]; then
    if [[ "${CONTENT_PATH}" == "/downloads/music/unsorted" ]]; then
        continue
    fi

    old_path="${CONTENT_PATH##*/}"
    timestamp="$(date "+%y%m%d%H%M%S")"

    status_code="$(
        curl \
            --silent \
            --output /dev/null \
            --write-out "%{http_code}" \
            --request POST \
            --data-urlencode "hash=${INFO_HASH}" \
            --data-urlencode "oldPath=${old_path}" \
            --data-urlencode "newPath=${old_path}-${timestamp}" \
            "http://localhost:8080/api/v2/torrents/renameFolder"
    )"

    echo "$(date) - auto music rename - ${status_code} - ${TORRENT_NAME}"
fi
