## Openstack helper scripts ##

This repository contains a set of scripts that assist in the administration of large Openstack private clouds



### Scripts list ###

openstack-snapshot-export-backup.sh - Export a snapshot done in Openstack with Ceph SDS as QCOW2 image file directly from Ceph as a backup


openstack-snapshotvms.sh - Create a daily snapshot of a list of virtual machines and their volumes in Openstack with auto-cleanup of old snapshots. Needs a config file with a list of machine names: /etc/snapshot-vm-list.conf and /root/openrc with authentication for the openstack cluster


openstack-snapshot-build-dynamic-list.sh -  This script creates a list of machines that have a the property backup=true set


openstack-snapshot-export-backup.sh - This script exports snapshots directly from Ceph rbd volumes by using directly qemu-img and getting the ids using openstack commands


openstack-snapshotvms-tags.sh - This script creates snapshots in Openstack if the storage backend supports them


passive-check-mon-tf.sh

