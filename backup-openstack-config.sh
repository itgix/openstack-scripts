#!/bin/bash

backup_dir="/openstack/backup/openstack-config"
backup_name="etc-$(date +%Y%m%d)"
backup_dir_today="${backup_dir}/${backup_name}"
KEEPDAYS=7

declare -a Controllers=(
infra1
infra2
infra3
)

echo "=========================START========================="

# Create backup directory for today's backup
mkdir -p $backup_dir_today

# BACKUP
# Loop through all controllers
for controller in "${Controllers[@]}"
do
    backup_dir_current="${backup_dir_today}/${controller}"
    # Create directory for the current controller backups
    mkdir -p $backup_dir_current

    # Backup controller's /etc
    # /etc/cinder and /etc/neutron are symlinks to /openstack/venvs/{cinder,neutron}-*/etc/{cinder,neutron} so we backup them separately
    echo "$(date) INFO: Backing up etc of controller ${controller}"
    rsync -e "ssh -q" -a ${controller}:/etc/ ${backup_dir_current}/${controller}-etc

    echo "$(date) INFO: Backing up /openstack/venvs/cinder-*/etc/cinder/ on ${controller}"
    rsync -e "ssh -q" -a ${controller}:/openstack/venvs/cinder-*/etc/cinder/ ${backup_dir_current}/${controller}-os-venv-cinder-etc
    echo "$(date) INFO: Backing up /openstack/venvs/neutron-*/etc/neutron/ on ${controller}"
    rsync -e "ssh -q" -a ${controller}:/openstack/venvs/neutron-*/etc/neutron/ ${backup_dir_current}/${controller}-os-venv-neutron-etc
    
    
    # Backup containers on the controller
    # /etc/nova in the nova_api container is a symlink to the container's /openstack/venvs/nova-*/etc/nova so we backup it separately
    nova_api_container=$(ssh -q ${controller} lxc-ls -f | grep "nova_api_container" | awk '{print $1}')
    echo "$(date) INFO: Backing up /openstack/venvs/nova-*/etc/nova/ on ${nova_api_container}"
    rsync -e "ssh -q" -a ${controller}:/var/lib/lxc/${nova_api_container}/rootfs/openstack/venvs/nova-*/etc/nova/ ${backup_dir_current}/${nova_api_container}-os-venv-nova-etc

    for lxc_container in $(ssh -q ${controller} lxc-ls -f | tail -n +2 | awk '{print $1}')
    do
        echo "$(date) INFO: Backing up etc of container ${lxc_container}"
        rsync -e "ssh -q" -a ${controller}:/var/lib/lxc/${lxc_container}/rootfs/etc/ ${backup_dir_current}/${lxc_container}-etc
    done
done

# COMPRESS
echo "$(date) INFO: Compressing today's backup"
cd ${backup_dir}
tar -czf "${backup_name}.tar.gz" ${backup_name} && rm -rf ${backup_dir_today}
#tar -czf "${backup_dir_today}.tar.gz" ${backup_dir_today} && echo "$(date) INFO: rm -rfi ${backup_dir_today}"

# CLEANUP
echo "$(date) INFO: Deleting backups older than ${KEEPDAYS} day(s)"
#find ${backup_dir} -name "etc-*tar.gz" -mtime +${KEEPDAYS} -delete -print
find ${backup_dir} -name "etc-*tar.gz" -mtime +${KEEPDAYS} -print # DRYRUN

#sed -i '/\*\|^$/d' /var/log/backup-openstack-config.log

echo "==========================END=========================="
