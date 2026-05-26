# Task 7 — Deploy Squid with a Galaxy Role

Create a playbook that uses the `squid` role (installed in Task 6) to deploy Squid on the load balancer nodes.

**Playbook path:** `/home/student/ansible/squid.yml`

## Requirements

### a) Target hosts

The play must run on hosts in the **`balancers`** host group.

### b) Apply the role

Use the `squid` role that was installed from Ansible Galaxy in the previous task.

> **Note:** Make sure the `squid` role is present under `/home/student/ansible/roles/` before running this playbook.
