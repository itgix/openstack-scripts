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
## variables defined in config file
# STORAGEBKPSRV="172.18.25.18"
# STORAGEBKPUSR="dr_backup_export"

let KEEPSECSAGO=$KEEPDAYS*3600*24

echo "================================================================================"
echo "`date +%Y%m%d-%H:%M` INFO Starting backup script for date $DATETIME ($TIMESTAMP) with retention of snapshots $KEEPDAYS days ($KEEPSECSAGO secs)"

let CLEANUPTIMESTAMP=$TIMESTAMP-$KEEPSECSAGO

CLEANUPDATETIME=`date --date @$CLEANUPTIMESTAMP +%Y%m%d`


echo "`date +%Y%m%d-%H:%M` INFO Calculating cleanup date $CLEANUPDATETIME ( $CLEANUPTIMESTAMP ) "


## Set openstack environment
source /root/openrc

## Clear machine attachments info file
echo "" > /tmp/snapshots-attachment-info.txt


if [[ "$DYNAMICLIST" == "true" ]]; then
  echo ""
  echo "`date +%Y%m%d-%H:%M` INFO building dynamic server list"
  ## build dynamic server list in /tmp/servers-to-backup.txt
  ## TODO: switch to mktemp
  LISTTEMPFILE=/tmp/allserverslist.txt
  LISTTOBACKUP=/tmp/servers-to-backup.txt
  
  #/usr/local/bin/openstack server list -c ID -f value --all-projects > $LISTTEMPFILE # TODO: use this line instead of the below (all-projects was removed to test faster)
  /usr/local/bin/openstack server list -c ID -f value > $LISTTEMPFILE
  
  ## cleanup file, but ensure there is no empty line at the start
  echo -n "" > $LISTTOBACKUP
  
  for srv in `cat $LISTTEMPFILE`
  do
    PROPERTIES=`/usr/local/bin/openstack server show $srv -f json -c properties`
    BACKUPENABLED=`echo $PROPERTIES | jq .properties.backup 2>/dev/null`
    PROPMISSING=$?
    # debug
    echo $srv $PROPMISSING $BACKUPENABLED
    if [ $PROPMISSING -eq 0 ]; then
       if [[ $BACKUPENABLED == '"true"' ]]; then
           echo $srv >> $LISTTOBACKUP
       fi
    fi
  done
  #/usr/local/bin/openstack-snapshot-build-dynamic-list.sh
  readarray -t SERVERLIST < $LISTTOBACKUP
fi

for SRV in "${SERVERLIST[@]}"
do
  echo ""
  echo "`date +%Y%m%d-%H:%M` INFO Creating snapshot for $SRV"
  DISPLAYNAME=`/usr/local/bin/openstack server show $SRV -c name -f value`

  # Creates new instance images
  echo "openstack server image create --name ${SRV}-${DISPLAYNAME}-snap-${DATETIME} $SRV --max-width 220"
  /usr/local/bin/openstack server image create --name "${SRV}-${DISPLAYNAME}-snap-${DATETIME}" $SRV --max-width 220

  # Print and store info about attached volumes to the instance (just for info it seems)
  echo ""
  echo "`date +%Y%m%d-%H:%M` INFO getting info about the attached volumes"
  ATTACHEDVOLS=`/usr/local/bin/openstack server show $SRV -f value -c volumes_attached`
  echo "$SRV $ATTACHEDVOLS" >> /tmp/snapshots-attachment-info.txt
  echo "`date +%Y%m%d-%H:%M` INFO attachments for machine $SRV are $ATTACHEDVOLS"

  # Deletes old instance images
  echo ""
  echo "`date +%Y%m%d-%H:%M` INFO cleaning up old image snapshot from $KEEPDAYS days ago ${SRV}-${DISPLAYNAME}-snap-${CLEANUPDATETIME}"
  echo "openstack image delete ${SRV}-${DISPLAYNAME}-snap-${CLEANUPDATETIME}"
  /usr/local/bin/openstack image delete ${SRV}-${DISPLAYNAME}-snap-${CLEANUPDATETIME}

  echo ""
  echo "`date +%Y%m%d-%H:%M` INFO cleanup old volume snapshots from $KEEPDAYS days ago "
  #echo openstack volume snapshot delete "snapshot for ${SRV}-snap-${CLEANUPDATETIME}"
  #/usr/local/bin/openstack volume snapshot delete "snapshot for ${SRV}-snap-${CLEANUPDATETIME}"
  ## Delete all snapshots of a given name
  snapidstodelete=""
  echo /usr/local/bin/openstack volume snapshot list --name "snapshot for ${SRV}-${DISPLAYNAME}-snap-${CLEANUPDATETIME}" -f value -c ID | xargs
  snapidstodelete=`/usr/local/bin/openstack volume snapshot list --name "snapshot for ${SRV}-${DISPLAYNAME}-snap-${CLEANUPDATETIME}" -f value -c ID | xargs`
  if [ ! -z "$snapidstodelete" ];
  then
    echo "`date +%Y%m%d-%H:%M` INFO deleting snapshots $snapidstodelete"
    echo "/usr/local/bin/openstack volume snapshot delete $snapidstodelete"
    /usr/local/bin/openstack volume snapshot delete $snapidstodelete
  else
    echo "`date +%Y%m%d-%H:%M` WARNING no snapshot ids found for the name snapshot for ${SRV}-${DISPLAYNAME}-snap-${CLEANUPDATETIME}"
  fi

done


## Send fresh snapshot list to Storpool storage server for exporting to external storage
# format: ID<space>name
#/usr/local/bin/openstack volume snapshot list -f value -c ID -c Name | grep "snap-${DATETIME}"  > /tmp/snapshots-list-for-today.txt # TODO: commented for the below experiment
/usr/local/bin/openstack volume snapshot list -f value -c ID -c Name | grep "snap-${DATETIME}" | awk '{print $1}' > /tmp/snapshots-list-for-today.txt

## TODO: experimental change (adds the device name and if it is bootable to the name) for easier recovery
#> /tmp/snapshots-list-for-today.txt
#
#for snapid in $(/usr/local/bin/openstack volume snapshot list -f value -c ID -c Name | grep "snap-${DATETIME}" | awk '{print $1}')
#do
#   snapname=$(/usr/local/bin/openstack volume snapshot show -f value -c name $snapid | sed 's/ /-/g')
#   volumeid=$(openstack volume snapshot show $snapid -f value -c volume_id)
#   devicename=$(openstack volume show $volumeid --fit-width -f json -c attachments | jq '.attachments[].device' | sed 's/\//-/g')
#   bootable=$(openstack volume show $volumeid -f value -c bootable)
#   echo "EXPORTING: $snapid ${snapname}${devicename:1:-1}-bootable-${bootable}"
#   echo "$snapid ${snapname}${devicename:1:-1}-bootable-${bootable}" >> /tmp/snapshots-list-for-today.txt
#done


scp /tmp/snapshots-list-for-today.txt  ${STORAGEBKPUSR}@${STORAGEBKPSRV}:/home/dr_backup_export/snapshot_list/snapshots-list-for-today.txt

echo "`date +%Y%m%d-%H:%M` INFO Ending backup script for date $DATETIME ($TIMESTAMP) with retention of snapshots $KEEPDAYS days ($KEEPSECSAGO secs)"
echo "================================================================================"
