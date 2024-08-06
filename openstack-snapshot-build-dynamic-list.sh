#!/bin/bash
## ITGix ltd. copyright 2022
## Author: Mihail Vukadinoff
# This script creates a list of machines that have a the property backup=true set

source  ~/openrc
## TODO: switch to mktemp
LISTTEMPFILE=/tmp/allserverslist.txt
LISTTOBACKUP=/tmp/servers-to-backup.txt

openstack server list -c ID -f value --all-projects > $LISTTEMPFILE

echo "" > $LISTTOBACKUP

for srv in `cat $LISTTEMPFILE`
do
  PROPERTIES=`openstack server show $srv -f json -c properties`
  BACKUPENABLED=`echo $PROPERTIES | jq .properties.backup 2>/dev/null`
  PROPMISSING=$?
  echo $srv $PROPMISSING $BACKUPENABLED
  if [ $PROPMISSING -eq 0 ]; then
     if [[ $BACKUPENABLED == '"true"' ]]; then
         echo $srv >> $LISTTOBACKUP
     fi
  fi
done

