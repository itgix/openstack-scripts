#!/bin/bash
## ITGix ltd. copyright
## Author: Mihail Vukadinoff
# This script creates snapshots in Openstack if the storage backend supports them


declare -a SERVERLIST

# Load settings 
# SERVERLIST - list of servers to snapshot their volumes
# Example: SERVERLIST=(prod-elastix-pbx01 prod-firmware-upd04)
# KEEPDAYS=7  - days to keep snapshots
. /etc/snapshot-vm-list.conf


DATETIME=`date +%Y%m%d`
TIMESTAMP=`date +%s`

let KEEPSECSAGO=$KEEPDAYS*3600*24

echo "`date +%Y%m%d-%H:%M` INFO Starting backup script for date $DATETIME ($TIMESTAMP) with retention of snapshots $KEEPDAYS days  ($KEEPSECSAGO secs) "

let CLEANUPTIMESTAMP=$TIMESTAMP-$KEEPSECSAGO

CLEANUPDATETIME=`date --date @$CLEANUPTIMESTAMP +%Y%m%d`


echo "`date +%Y%m%d-%H:%M` INFO Calculating cleanup date $CLEANUPDATETIME ( $CLEANUPTIMESTAMP ) "


## Set openstack environment

source /root/openrc

for SRV in "${SERVERLIST[@]}"
do
  echo "`date +%Y%m%d-%H:%M` INFO Creating snapshot for $SRV"
  echo openstack server image create --name ${SRV}-snap-${DATETIME}  $SRV
  /usr/local/bin/openstack server image create --name ${SRV}-snap-${DATETIME}  $SRV
  echo "`date +%Y%m%d-%H:%M` INFO cleaning up old image snapshot from $KEEPDAYS days ago ${SRV}-snap-${CLEANUPDATETIME}"
  echo openstack image delete ${SRV}-snap-${CLEANUPDATETIME}
  /usr/local/bin/openstack image delete ${SRV}-snap-${CLEANUPDATETIME}
  echo "`date +%Y%m%d-%H:%M` INFO cleanup old volume snapshots from $KEEPDAYS days ago "
  #echo openstack volume snapshot delete "snapshot for ${SRV}-snap-${CLEANUPDATETIME}"
  #/usr/local/bin/openstack volume snapshot delete "snapshot for ${SRV}-snap-${CLEANUPDATETIME}"
  ## Delete all snapshots of a given name
  snapidstodelete=""
  echo /usr/local/bin/openstack volume snapshot list --name "snapshot for ${SRV}-snap-${CLEANUPDATETIME}" -f value -c ID | xargs
  snapidstodelete=`/usr/local/bin/openstack volume snapshot list --name "snapshot for ${SRV}-snap-${CLEANUPDATETIME}" -f value -c ID | xargs`
  if [ ! -z "$snapidstodelete" ];
  then
    echo "`date +%Y%m%d-%H:%M` INFO deleting snapshots $snapidstodelete"
    echo /usr/local/bin/openstack volume snapshot delete $snapidstodelete
    /usr/local/bin/openstack volume snapshot delete $snapidstodelete
  else
    echo "`date +%Y%m%d-%H:%M` INFO no snapshot ids found for the name snapshot for ${SRV}-snap-${CLEANUPDATETIME}"
  fi

done

