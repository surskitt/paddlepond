# Initial cluster setup

## Installing ubuntu server

Download and write ubuntu server edition to a usb drive.

Create a second usb drive with label "cidata" and copy the two files within `cloud-init` to the root of the drive.

Insert both drives to machine, power on and ssh to installer@host with password `password`.

Complete installation.

## Setup server

Use `ssh-copy-id` to copy ssh public key to servers.

Use the `prepare.yaml` playbook to prepare the base ubuntu operating system for k3s.

    ansible-playbook -i inventory prepare.yaml -e ansible_user=shane -e ansible_become_pass="$(pass pass)"

## Installing k3s

Use the `install.yaml` playbook to install k3s on the servers.

    ansible-playbook -i inventory install.yaml 

## Install flux

Use the `flux.yaml` playbook to setup requisite secrets then install flux on the servers.

    ansible-playbook -i inventory flux.yaml

## Combining above steps

There is a `playbook.yaml` that can be used instead to run all the above playbooks one after the other.

    ansible-playbook -i inventory playbook.yaml -e ansible_user=shane -e ansible_become_pass="$(pass pass)"

## Restore from backups

Copy snapshot data from nfs restic to local restic

    RESTIC_SERVER=
    RESTIC_NFS_SERVER=

    for i in $(kubectl get repo -A -l restic-instance=local -o name); do restic -r "rest:https://${RESTIC_SERVER}/paddlepond/${i##*/}" init; done

    for i in $(kubectl get repo -A -l restic-instance=local -o name); do restic -r "rest:https://${RESTIC_NFS_SERVER}/paddlepond/${i##*/}" copy --repo2 "rest:https://${RESTIC_SERVER}/paddlepond/${i##*/}"; done

Create restore sessions

    for i in $(find kube -name backuprestoresession.yaml); do kubectl apply -f "${i}"; done

Delete restore sessions once backups complete

    for i in $(find kube -name backuprestoresession.yaml); do kubectl delete -f "${i}"; done