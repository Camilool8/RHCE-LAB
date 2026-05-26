# Task 6 — Download Roles with Ansible Galaxy

Use Ansible Galaxy and a requirements file to download and install three community roles.

**Requirements file path:** `/home/student/ansible/roles/requirements.yml`

**Roles destination:** `/home/student/ansible/roles`

## Requirements

The `requirements.yml` file must define the three roles below. Install them all with a single `ansible-galaxy` command.

### Role 1 — zabbix

| Field | Value |
|-------|-------|
| Source URL | `https://galaxy.ansible.com/download/zabbix-zabbix-1.0.6.tar.gz` |
| Installed name | `zabbix` |

### Role 2 — security

| Field | Value |
|-------|-------|
| Source URL | `https://galaxy.ansible.com/download/openafs_contrib-openafs-1.9.0.tar.gz` |
| Installed name | `security` |

### Role 3 — squid

| Field | Value |
|-------|-------|
| Source URL | `https://galaxy.ansible.com/download/mafalb-squid-0.2.0.tar.gz` |
| Installed name | `squid` |
