# Task 1 — Install and Configure Ansible

Install and configure Ansible on the control node (`ansible-server`).

## Requirements

### a) Install the required packages

Install `ansible-core` **and `ansible-navigator`** on the control node.
`ansible-navigator` is the runner the EX294 exam uses — every later task
in this lab is meant to be runnable with both `ansible-playbook` and
`ansible-navigator run`.

Confirm both are installed:

```bash
ansible --version
ansible-navigator --version
```

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

### d) Configure `ansible-navigator`

**Path:** `/home/student/.ansible-navigator.yml`

Configure `ansible-navigator` so that every later task can be run with:

```bash
ansible-navigator run <playbook>.yml
```

Minimum settings the file must establish:

| Setting | Value |
|---------|-------|
| `execution-environment.enabled` | `true` |
| `execution-environment.image` | `ghcr.io/ansible/community-ansible-dev-tools:latest` |
| `execution-environment.container-engine` | `podman` |
| `execution-environment.pull.policy` | `missing` |
| `execution-environment.volume-mounts[0]` | `/usr/share/ansible/roles → /usr/share/ansible/roles (ro)` |
| `mode` | `stdout` |
| `playbook-artifact.enable` | `false` |

`execution-environment.enabled: true` mirrors EX294, where every play runs
inside an automation execution environment. The community EE image used by
the lab does not ship `rhel-system-roles`, so the `volume-mounts` entry
bind-mounts the host's role directory into the container — without it,
tasks 4 and 18 fail with *role 'rhel-system-roles.X' was not found*. (On
the real exam Red Hat ships the system roles as a collection tarball you
install into your project; the bind-mount is the lab-side equivalent.)
`playbook-artifact.enable: false` stops every run from dropping a
`<playbook>-artifact-<timestamp>.json` next to your playbook.

> The lab ships this file pre-configured for you (see
> [Use ansible-navigator](../../docs/how-to/use-ansible-navigator.md)),
> but you should be able to write it from scratch on the exam.
