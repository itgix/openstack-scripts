#!/bin/bash

backup_dir="/openstack/backup/openstack-databases"
KEEPDAYS=7

declare -a Databases=(
aodh
cinder
designate
glance
gnocchi
heat
keystone
masakari
neutron
nova
nova_api
nova_cell0
placement
rally
)

echo "=========================START========================="

# DUMP
echo "$(date): Starting dumping process"

for db in "${Databases[@]}"
do
  filename="${backup_dir}/os-db-${db}-$(eval date +%Y%m%d).sql.gz"

  # Dump the current DB
  echo "$(date): Currently dumping database: ${db}"
  /usr/bin/mysqldump -uroot -pEvoOpnStackRul3z -h infra1_galera_container-56032a45 ${db} | gzip > $filename
done

# CLEANUP
echo ""
echo "$(date): Cleaning up database backups older than ${KEEPDAYS}"

if [ "$backup_dir" == "/" ];then
 echo Root / not allowed
 exit 1;
fi

find ${backup_dir} -name "os-db-*.sql.gz" -mtime +${KEEPDAYS} -delete -print

echo "==========================END=========================="
