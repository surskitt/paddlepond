# Initial cluster setup

## Installing ubuntu server

Download and install ubuntu server edition.

It should be possible to include an autoinstall file in the install medium to allow ssh with a preset password to complete install.

## Setup server

Install nfs-common

Remount /mnt/usb

## Installing k3s

Setup ssh access to root user.

Run k3sup to install k3s onto server.

    k3sup install --ip 192.168.2.5 --ssh-key ~/.ssh/id_rsa --local-path ~/.kube/config --k3s-extra-args '--no-deploy traefik'

## Install flux

Set GITHUB_TOKEN environment variable
    
    export GITHUB_TOKEN="$(pass github_paddlepond_personal_access_token)"

Install flux using cli

    flux bootstrap github \
      --owner=shanedabes \
      --repository=paddlepond \
      --path=kube \
      --personal

Get sealed secrets cert

    kubeseal --fetch-cert \
      --controller-namespace=sealed-secrets \
      --controller-name=sealed-secrets > kube/infra/sealed-secrets/cert.pem

Generate new stash license key from website and edit pass password

    pass edit ss edit paddlepond/stash/licensea

Reseal sealed secrets

    kube/seal.sh

## Restore from backups

Copy snapshot data from nfs restic to local restic

    RESTIC_SERVER=
    RESTIC_NFS_SERVER=

    for i in $(kubectl get repo -A -l restic-instance=local -o name); do restic -r "rest:https://${RESTIC_SERVER}/paddlepond/${i##*/}" init; done

    for i in $(kubectl get repo -A -l restic-instance=local -o name); do restic -r "rest:https://${RESTIC_NFS_SERVER}/paddlepond/${i##*/}" copy --repo2 "rest:https://${RESTIC_SERVER}/paddlepond/${i##*/}"; done

Create restore sessions

    for i in $(find kube -name backuprestoresession.yaml); do kubectl apply -f "${i}"; done
