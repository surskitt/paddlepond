#!/usr/bin/env bash

curl -X POST "http://cross-seed.media.svc.cluster.local/api/webhook?apikey=${CROSS_SEED_API_KEY}" -d "infoHash=${TR_TORRENT_HASH}"
