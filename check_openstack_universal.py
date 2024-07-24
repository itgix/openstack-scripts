#!/usr/bin/python3 -W ignore

import subprocess, sys, json
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter


parser = ArgumentParser(description=__doc__,
                formatter_class=ArgumentDefaultsHelpFormatter)

parser.add_argument("-s", "--service",
                    dest="openstack_service",
                    type=str,
                    default='nova',
                    help="Choose which openstack service to check")
"""
parser.add_argument("-m", "--metric",
                    dest="smart_metrics",
                    default=[],
                    action='append',
                    help="Smart Metric to check")
"""
parser.add_argument("-i", "--instance",
                    dest="openstack_instance",
                    type=str,
                    help="Choose which openstack instance to check")
parser.add_argument("-d", "--debug",
                   dest="action_debug",
                   action='store_true',
                   default=False,
                   help="Enables output mode: debug")
parser.add_argument("--ignore",
                    dest="ignore_list",
                    default=[],
                    action='append',
                    help="List of Containers to ignore from status check")

args = parser.parse_args()

def sanity_check():
    openstack_services = ["nova", "cinder", "lxc", "compute", "neutron", "galera", "instance"]
    if args.openstack_service not in openstack_services:
        print(f"Unexpected service {args.openstack_service}")
        sys.exit(3)
    else:
        if args.action_debug:
            print(f"Matched servicecheck {args.openstack_service}. Proceeding with check")

def get_lxc_containers():
    container_cmd = ["sudo", "/usr/bin/lxc-ls", "--fancy"]
    containers = subprocess.check_output(container_cmd).decode('utf-8').splitlines()

    for line in containers:
        utility_container = [s for s in line.split() if "utility_container" in s]
        if len(utility_container) > 0:
            break

    for line in containers:
        galera_container = [s for s in line.split() if "galera_container" in s]
        if len(galera_container) > 0:
            break

    return containers, utility_container[0], galera_container[0]


def check_lxc_status(input):
    input.pop(0)
    status = 0
    message = ""
    for line in input:
        line_list = line.split()
        name = line_list[0]
        state = line_list[1]

        if name in args.ignore_list:
            continue

        if state != 'RUNNING':
            message += f"PROBLEM: Found container {name} in state ({state})\n"
            if status > 1:
                status = 2
            else:
                status = 1

    if message == "":
        message = "OK: All LXC Containers are running"

    return status, message


def check_nova_services(utility_container):
    nova_services_cmd = f"sudo su - root -c \"lxc-attach {utility_container} -- /usr/bin/bash -c \'source /root/openrc && nova service-list\'\""
    nova_services = subprocess.check_output(nova_services_cmd, shell=True).decode('utf-8').splitlines()
    nova_services.pop(0)
    nova_services.pop(0)
    nova_services.pop(0)
    nova_services.pop(-1)

    message = ""
    status = 0
    for line in nova_services:
        line_splt = line.split('|')
        line_splt.remove('')
        svc_type = line_splt[1].strip()
        svc_name = line_splt[2].strip()
        svc_status = line_splt[5].strip()

        if args.action_debug:
            print(f"Checking Nova Service {svc_type} {svc_name} - Status: {svc_status}")

        if svc_status.lower() != "up":
            message += f"PROBLEM: Found NOVA service {svc_type} {svc_name} in state ({svc_status})\n"
            if status > 1:
                status = 2
            else:
                status = 1

    if message == "":
        message = "OK: All Nova Services are running"

    return status, message


def check_cinder_services(utility_container):
    cinder_services_cmd = f"sudo su - root -c \"lxc-attach {utility_container} -- /usr/bin/bash -c \'source /root/openrc && cinder service-list\'\""
    cinder_services = subprocess.check_output(cinder_services_cmd, shell=True).decode('utf-8').splitlines()
    cinder_services.pop(0)
    cinder_services.pop(0)
    cinder_services.pop(0)
    cinder_services.pop(-1)

    message = ""
    status = 0
    for line in cinder_services:
        line_splt = line.split('|')
        line_splt.remove('')
        svc_type = line_splt[0].strip()
        svc_name = line_splt[1].strip()
        svc_status = line_splt[4].strip()

        if args.action_debug:
            print(f"Checking Cinder Service {svc_type} {svc_name} - Status: {svc_status}")

        if svc_status.lower() != "up":
            message += f"PROBLEM: Found Cinder service {svc_type} {svc_name} in state ({svc_status})\n"
            if status > 1:
                status = 2
            else:
                status = 1

    if message == "":
        message = "OK: All Cinder Services are running"

    return status, message


def check_compute_services(utility_container):
    compute_services_cmd = f"sudo su - root -c \"lxc-attach {utility_container} -- /usr/bin/bash -c \'source /root/openrc && openstack compute service list\'\""
    compute_services = subprocess.check_output(compute_services_cmd, shell=True).decode('utf-8').splitlines()
    compute_services.pop(0)
    compute_services.pop(0)
    compute_services.pop(0)
    compute_services.pop(-1)

    message = ""
    status = 0
    for line in compute_services:
        line_splt = line.split('|')
        line_splt.remove('')
        svc_type = line_splt[1].strip()
        svc_name = line_splt[2].strip()
        svc_status = line_splt[5].strip()

        if args.action_debug:
            print(f"Checking Compute Service {svc_type} {svc_name} - Status: {svc_status}")

        if svc_status.lower() != "up":
            message += f"PROBLEM: Found Compute service {svc_type} {svc_name} in state ({svc_status})\n"
            if status > 1:
                status = 2
            else:
                status = 1

    if message == "":
        message = "OK: All Compute Services are running"

    return status, message



def check_neutron_services(utility_container):
    neutron_services_cmd = f"sudo su - root -c \"lxc-attach {utility_container} -- /usr/bin/bash -c \'source /root/openrc && openstack network agent list\'\""
    neutron_services = subprocess.check_output(neutron_services_cmd, shell=True).decode('utf-8').splitlines()
    neutron_services.pop(0)
    neutron_services.pop(0)
    neutron_services.pop(0)
    neutron_services.pop(-1)

    message = ""
    status = 0
    for line in neutron_services:
        line_splt = line.split('|')
        line_splt.remove('')
        svc_type = line_splt[1].strip()
        svc_name = line_splt[2].strip()
        svc_status = line_splt[5].strip()

        if args.action_debug:
            print(f"Checking Neutron Agent {svc_type} {svc_name} - Status: {svc_status}")

        if svc_status.lower() != "up":
            message += f"PROBLEM: Found Neutron Agent {svc_type} {svc_name} in state ({svc_status})\n"
            if status > 1:
                status = 2
            else:
                status = 1

    if message == "":
        message = "OK: All Neutron Agents are running"

    return status, message


def check_galera_status(galera_container):
    wsrep_cmd = f"sudo lxc-attach {galera_container} -- /usr/bin/bash -c \"mysql -e \'SHOW GLOBAL STATUS;\';\""
    wsrep_out = subprocess.check_output(wsrep_cmd, shell=True).decode('utf-8').splitlines()
    max_connections_cmd = f"sudo lxc-attach {galera_container} -- /usr/bin/bash -c \"mysql -e \'SHOW VARIABLES LIKE \\\"max_connections\\\";\';\""
    max_connections_out = subprocess.check_output(max_connections_cmd, shell=True).decode('utf-8').splitlines()

    perf_dict = {}
    for line in wsrep_out:
        perf_keys_list = (
                         "wsrep_ready",
                         "wsrep_local_state_comment",
                         "wsrep-cluster_size",
                         "wsrep_connected",
                         "Bytes_received",
                         "Bytes_sent",
                         "Com_select",
                         "Com_update",
                         "Com_delete",
                         "Com_insert",
                         "Com_rollback",
                         "Open_files",
                         "Opened_files",
                         "wsrep_cluster_size",
                         "wsrep_local_state_comment",
                         "wsrep_cluster_status",
                         "Connection_errors_internal",
                         "Connection_errors_max_connections",
                         "Aborted_connects",
                         "Aborted_clients",
                         "Innodb_buffer_pool_reads",
                         "Innodb_buffer_pool_read_requests",
                         "Innodb_buffer_pool_pages_total",
                         "Innodb_buffer_pool_pages_free",
                         "Innodb_page_size",
                         "Innodb_row_lock_waits",
        )

        perf_key = line.split()[0]
        if perf_key in perf_keys_list:
            try:
                perf_value = int(line.split()[1])
            except ValueError as e:
                if args.action_debug:
                    message += f'DEBUG: Key {perf_key} does NOT have an integer value : {line.split()[1]}\n{e}'
                perf_value = line.split()[1]
            perf_dict[perf_key] = perf_value

    for line in max_connections_out:
        if 'max_connections' in line:
            perf_value = int(line.split()[1])
            perf_dict['max_connections'] = perf_value

    perf_dict['db_writes'] = perf_dict['Com_insert'] + perf_dict['Com_update'] + perf_dict['Com_delete']
    perf_dict['innodb_buffer_pool_efficiency'] = (perf_dict['Innodb_buffer_pool_reads'] / perf_dict ['Innodb_buffer_pool_read_requests']) * 100
    perf_dict['innodb_buffer_pool_utilization'] = ((perf_dict['Innodb_buffer_pool_pages_total'] - perf_dict['Innodb_buffer_pool_pages_free']) / perf_dict['Innodb_buffer_pool_pages_total']) * 100
    perf_dict['innodb_buffer_pool_size'] = perf_dict['Innodb_buffer_pool_pages_total'] * perf_dict['Innodb_page_size']


    message = ""
    status = 0
    if perf_dict['wsrep_ready'] != "ON":
        message += f'Problem with wsrep_ready - status {wsrep_ready}\n' # critical
        status = 2
    if perf_dict['wsrep_local_state_comment'] != "Synced":
        message += f'Problem with galera sync - status {wsrep_local_state_comment}\n' # critical
        status = 2
    if perf_dict['wsrep_connected'] != "ON":
        message += f'Problem with wsrep connection - status: {wsrep_connected}\n' # critical
        status = 2
    if perf_dict['wsrep_cluster_size'] == 2:
        if status != 2:
            status = 1
        message += f'Problem with galera cluster size - nodes: {wsrep_cluster_size}\n' # critical if <2; warning if ==2
    elif perf_dict['wsrep_cluster_size'] < 2:
        status = 2
        message += f'Problem with galera cluster size - nodes: {wsrep_cluster_size}\n' # critical if <2; warning if ==2

    if message == "":
        message = "OK: No problems found with wsrep_ready, wsrep_local_state_comment, wsrep_cluster_size, wsrep_connected"

    perf_dict['wsrep_local_state_comment'] = 2 if perf_dict['wsrep_local_state_comment'] == 'Synced' else 0
    perf_dict['wsrep_cluster_status'] = 2 if perf_dict['wsrep_cluster_status'] == 'Primary' else 0

    perfdata = ''
    for perf_key, perf_value in perf_dict.items():
        if isinstance(perf_value, int) or isinstance(perf_value, float):
            perfdata += f" {perf_key}={perf_value};"
        else:
            if args.action_debug:
                message += f'DEBUG: {perf_key} does NOT have a number value ({perf_value}) hence will not be set as perf data'

    message += f" |{perfdata}"

    return status, message

def check_openstack_instance(utility_container, instance_id):
    message = ""
    status = 0

    openstack_instance_cmd = f"sudo su - root -c \"lxc-attach {utility_container} -- /usr/bin/bash -c \'source /root/openrc && openstack server show -f value -c OS-EXT-STS:power_state -c OS-EXT-STS:vm_state -c status {instance_id}\'\""
    openstack_instance = []

    try:
        openstack_instance = subprocess.check_output(openstack_instance_cmd, shell=True, stderr=subprocess.STDOUT).decode('utf-8').splitlines()
    except subprocess.CalledProcessError as e:
        error_output = e.output
        message += f"{error_output}\n"
        message = message[2:-2]
        status = 2
        return status, message

    output_lines_count = len(openstack_instance)

    if output_lines_count == 3:
        power_state, vm_state, instance_status = openstack_instance
        if (power_state != "Running" and power_state != "1") or vm_state != "active" or instance_status != "ACTIVE":
            message += f"PROBLEM: Instance details - power_state: {power_state}, vm_state: {vm_state}, status: {instance_status}\n"
            status = 1
    else:
        message += f"Unexpected result, try running the following command manually:\nopenstack server show -f value -c OS-EXT-STS:power_state -c OS-EXT-STS:vm_state -c status {instance_id}\n"
        status = 2

    if message == "":
        message = f"OK: Instance {instance_id} was queried successfully"

    return status, message

def main():
    sanity_check()
    containers, utility_container, galera_container = get_lxc_containers()

    if args.openstack_service == "instance" and args.openstack_instance != "":
        instance_id = args.openstack_instance

        status, message = check_openstack_instance(utility_container, instance_id)
        print(message)
        sys.exit(status)

    elif args.openstack_service == "lxc":
        status, message = check_lxc_status(containers)
        print(message)
        sys.exit(status)

    elif args.openstack_service == "nova":
        status, message = check_nova_services(utility_container)
        print(message)
        sys.exit(status)

    elif args.openstack_service == "cinder":
        status, message = check_cinder_services(utility_container)
        print(message)
        sys.exit(status)

    elif args.openstack_service == "compute":
        status, message = check_compute_services(utility_container)
        print(message)
        sys.exit(status)

    elif args.openstack_service == "neutron":
        status, message = check_neutron_services(utility_container)
        print(message)
        sys.exit(status)

    elif args.openstack_service == "galera":
        status, message = check_galera_status(galera_container)
        print(message)
        sys.exit(status)


if __name__ == '__main__':
    main()
