#!/usr/bin/env sh

time="$(date +%s)"

red_upload="$(curl -s -H "Authorization: ${RED_API_KEY}" "https://redacted.sh/ajax.php?action=user&id=${RED_USER_ID}" | jq '.response.stats.uploaded')"
ops_upload="$(curl -s -H "Authorization: ${OPS_API_KEY}" "https://orpheus.network/ajax.php?action=user&id=${OPS_USER_ID}" | jq '.response.stats.uploaded')"

echo "red upload: ${red_upload}"
echo "ops upload: ${ops_upload}"

if [ -z "${red_upload}" ] ; then
    red_upload=0
fi

if [ -z "${ops_upload}" ] ; then
    ops_upload=0
fi

echo "${time},${red_upload},${ops_upload}" >> /downloads/stats.txt
