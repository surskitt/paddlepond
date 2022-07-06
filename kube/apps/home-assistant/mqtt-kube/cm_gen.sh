#!/usr/bin/env bash

SCRIPT_DIR="$(dirname ${0})"

cat << EOF > "${SCRIPT_DIR}/configmap.yaml"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mqtt-kube-config
  namespace: home-assistant
data:
  config.yaml: |
    mqtt:
      host: mosquitto
      port: 1883
      client-id: mqtt-kube
      topic-prefix: mqtt-kube

    http:
      host: 0.0.0.0
      port: 8080
      max-connections: 10

    logging:
      level: DEBUG

    bindings:
EOF

for deploy in calibre-web flood jackett komga mylar nzbget plex pyload radarr sonarr transmission; do
    cat << EOF >> "${SCRIPT_DIR}/configmap.yaml"
      - namespace: media
        resource: Deployment
        name: ${deploy}

        patch:
          - topic: ${deploy}/power/set
            locus: "spec.replicas"
            values:
              map:
                "ON": 1
                "OFF": 0

        watch:
          - locus: "status.availableReplicas"
            topic: ${deploy}/power/state
            retain: true
            qos: 1
            values:
              map:
                1: "ON"
                ~: "OFF"

EOF
done

cat << EOF >> "${SCRIPT_DIR}/configmap.yaml"
      - namespace: restic
        resource: deployment
        name: restic-rest-server-nfs

        patch:
          - topic: resticnfs/power/set
            locus: "spec.replicas"
            values:
              map:
                "ON": 1
                "OFF": 0

        watch:
          - locus: "status.availableReplicas"
            topic: resticnfs/power/state
            retain: true
            qos: 1
            values:
              map:
                1: "ON"
                ~: "OFF"
EOF
