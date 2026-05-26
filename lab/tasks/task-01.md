# Task 1 — Install and Configure Ansible

Install and configure Ansible on the control node (`ansible-server`).

## Requirements

### a) Install the required packages

Install `ansible-core` (and any other necessary packages) on the control node.

### b) Create a static inventory file

**Path:** `/home/student/ansible/inventory`

Assign each node to its host group as follows:

| Node | Host Group |
|------|-----------|
| `node1` | `dev` |
| `node2` | `test` |
| `node3` | `prod` |
| `node4` | `prod` |
| `node5` | `balancers` |

- The `prod` group must be a **child** of the `webservers` group.

### c) Create an Ansible configuration file

**Path:** `/home/student/ansible/ansible.cfg`

The configuration file must set the following defaults:

| Setting | Value |
|---------|-------|
| Inventory file | `/home/student/ansible/inventory` |
| Default collections directory | `/home/student/ansible/mycollection` |
| Default roles directory | `/home/student/ansible/roles` |
