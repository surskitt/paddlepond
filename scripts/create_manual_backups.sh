#!/usr/bin/env bash

wait_for_job() {
    job="${1}"

    while sleep 1 ; do 
        status="$(kubectl --namespace "${namespace}" get pod -l job-name="${job}" -o jsonpath='{.items[*].status.phase}')"
        if [[ "${status}" == "Pending" ]]; then
            return
        fi
        # echo -n "."
    done
}

kubectl get replicationsources -A -o json | jq -r -c '.items[]' | while read -r rs ; do
    name="$(jq -r '.metadata.name' <<< "${rs}")"
    namespace="$(jq -r '.metadata.namespace' <<< "${rs}")"

    # patch in manual trigger to run backup now
    kubectl -n "${namespace}" patch replicationsources "${name}" --type merge -p '{"spec":{"trigger":{"manual":"'"$(date +%H%M%S)"'"}}}'

    # wait for job creation
    job="volsync-src-${name}"
    wait_for_job "${job}"

    # wait for job completion
    kubectl -n "${namespace}" wait "job/${job}" --for condition=complete --timeout=120m

    # remove manual trigger from backup
    kubectl -n "${namespace}" patch replicationsources "${name}" --type=json -p='[{"op": "remove", "path": "/spec/trigger/manual"}]'

    kubectl -n "${namespace}" get replicationsources "${name}"
done
