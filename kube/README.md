# K3S cluster

## Provisoning using k3sup

k3sup install --user shane --ip 192.168.2.4 --local-path ~/.kube/config --k3s-extra-args '--no-deploy traefik' --k3s-version VERSION
