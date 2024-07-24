#!/bin/bash
## ITGix ltd. copyright
## Author: Mihail Vukadinoff
# This script exports snapshots directly from Ceph rbd volumes by using directly qemu-img and getting the ids using openstack commands

BACKUPSERVER=<hostname>
BACKUPUSER=root
BACKUPPATH=/mnt/home/Openstack_backup

declare -a SERVERLIST

# Load settings 
# SERVERLIST - list of servers to snapshot their volumes
# Example: SERVERLIST=(server1 server2)
. /etc/snapshot-vm-list.conf

DATETIME=`/usr/bin/date +%Y%m%d`
TIMESTAMP=`/usr/bin/date +%s`

echo "`/usr/bin/date +%Y%m%d-%H:%M` INFO Starting backup script exporting snashot as image files for date $DATETIME ($TIMESTAMP)"

## Set openstack environment

source /root/openrc

for SRV in "${SERVERLIST[@]}"
do
  echo "`/usr/bin/date +%Y%m%d-%H:%M` INFO Getting snapshots for the server $SRV"
  # This exports the id variable as $vol is looking like id=XXXXX
  snapids=`/usr/local/bin/openstack volume snapshot list --name "snapshot for $SRV-snap-$DATETIME" -f value -c ID | xargs`
  exitcodeshap=$?
  for snapid in $snapids
  do
     if [ -z "$snapid" ] || [ $exitcodeshap -gt 0 ]; then
        echo "`/usr/bin/date +%Y%m%d-%H:%M` ERROR Could not get snapshot ID by name \"snapshot for $SRV-snap-$DATETIME\" "
     else
        echo "`/usr/bin/date +%Y%m%d-%H:%M` INFO Found snapshot for $SRV-snap-$DATETIME with id $snapid "
        volumeid=`/usr/local/bin/openstack volume  snapshot show  $snapid -f value -c volume_id`
        echo "`/usr/bin/date +%Y%m%d-%H:%M` INFO Exporting snapshot on backup server ${BACKUPSERVER} $SRV-snap-$DATETIME with id ${snapid} for volume ${volumeid} "
        echo /usr/bin/ssh ${BACKUPUSER}@${BACKUPSERVER} qemu-img convert -f raw -O qcow2 rbd:volumes/volume-${volumeid}@snapshot-${snapid} $BACKUPPATH/$SRV-snapshot-export-$DATETIME-${volumeid}.qcow2
        /usr/bin/ssh ${BACKUPUSER}@${BACKUPSERVER} qemu-img convert -f raw -O qcow2 rbd:volumes/volume-${volumeid}@snapshot-${snapid} $BACKUPPATH/$SRV-snapshot-export-$DATETIME-${volumeid}.qcow2
     fi
  done
done
