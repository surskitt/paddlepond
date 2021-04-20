#!/usr/bin/env bash

dirname="${0%/*}"

if [[ "${1}" == "." ]]; then
    search_dir="${PWD}"
else
    search_dir="${1}"
fi

if [[ -n "${1}" ]] ;then
    ansible-playbook "${dirname}/seal.yaml" -e search_dir="${search_dir}"
else
    ansible-playbook "${dirname}/seal.yaml"
fi
