set quiet
set minimum-version := '1.55.1'
set default-list
set default-script
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

[group('bootstrap-mallard')]
mod? bootstrap-mallard 'bootstrap/mallard'

[group('kubernetes-mallard')]
mod? kube-mallard 'kube/mallard'

[group('talos-mallard')]
mod? talos-mallard 'talos/mallard'

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}
