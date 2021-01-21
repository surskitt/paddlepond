#!/usr/bin/env bash

set -eo pipefail

usage() {
    echo "Usage: ${0} [-p PUB_KEY] [-f SECRETS_TEMPLATE]"
    echo "Options:"
    echo "  -p    location of the sealed secrets public key (defaults to SCRIPT_DIR/pub-key.pem"
    echo "  -f    template single specific file"
    echo "  -i    interactively fill missing environment variables"
    echo "  -h    show this help"
}

check_dep() {
    dep="${1}"

    if ! type "${dep}" >/dev/null 2>&1; then
        echo "Error: ${dep} is not installed" >&2
        exit 1
    fi
}

check_opt() {
    if [ -z "${1}" ]; then
        echo "${2}" >&2
        echo >&2
        usage >&2
        exit 1
    fi
}

check_dep envsubst
check_dep kubeseal
check_dep find
check_dep grep

D="$(dirname "${0}")"

PUB_KEY_FN="${D}/infra/sealed-secrets/cert.pem"
SECRET_FILE_SEARCH="${D}"
INTERACTIVE=false

while getopts 'p:f:ih' opt; do
    case "${opt}" in
        p)
            PUB_KEY_FN="${OPTARG}"
            ;;
        f)
            SECRET_FILE_SEARCH="${OPTARG}"
            ;;
        i)
            INTERACTIVE=true
            ;;
        h)
            usage
            exit
            ;;
        ?)
            usage >&2
            exit 1
            ;;
    esac
done

# if env file is piped in, source it
if [ -p /dev/stdin ]; then
    # shellcheck disable=SC1091
    source /dev/stdin
fi

# recursively save all *_secret.yaml.tmpl files to an array
readarray -d '' secretfiles < <(find "${SECRET_FILE_SEARCH}" -name '*secrets.yaml.tmpl' -print0)

if [[ "${#secretfiles[@]}" -eq 0 ]]; then
    echo "No secret files found" >&2
    exit 1
fi

# extract all environment variable names from secret files
env_vars="$(grep -Po '\$\{?\K[^ \"\}]*' "${secretfiles[@]}")"

# find all unset environment variables
env_not_set=()
for e in ${env_vars}; do
    if [[ "${!e}" == "" ]]; then
        env_not_set+=("${e}")
    fi
done

# if there are unset env vars, either exit or read them if in interactive mode
if [[ "${#env_not_set[@]}" -gt 0 ]]; then
    if ! "${INTERACTIVE}"; then
        echo "env vars not set: ${env_not_set[*]}"
        exit 1
    fi

    for e in "${env_not_set[@]}"; do
        echo -n "${e}: "
        read -r "${e?}"
    done
fi

# Seal all files using templates and environment variables
for s in "${secretfiles[@]}"; do
    fn="${s%%.tmpl}"
    echo "Sealing ${fn}"
    t="$(envsubst < "${s}")"
    kubeseal --format=yaml --cert="${PUB_KEY_FN}" <<< "${t}" > "${fn}"
done
