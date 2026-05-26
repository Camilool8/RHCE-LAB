# Task 18 — Configure SELinux with a System Role

Use the `selinux` RHEL system role to manage SELinux mode across all managed nodes.

## Requirements

### a) Create `selinux.yml` — permissive mode

**Playbook path:** `/home/student/ansible/selinux.yml`

- Target: **all** managed hosts.
- Use the `selinux` role from `rhel-system-roles`.
- Set the **default SELinux mode** to **`permissive`**.

### b) Verify SELinux mode — permissive

After running `selinux.yml`, confirm the SELinux mode on all nodes using an Ansible ad-hoc command:

```bash
ansible all -m command -a "getenforce"
```

### c) Create `selinux2.yml` — enforcing mode

**Playbook path:** `/home/student/ansible/selinux2.yml`

- Copy `selinux.yml` to `selinux2.yml`.
- Change the default SELinux mode to **`enforcing`** for all managed nodes.

### d) Run `selinux2.yml` with `ansible-navigator`

Execute the enforcing playbook using `ansible-navigator`:

```bash
ansible-navigator run selinux2.yml
```

### e) Verify SELinux mode — enforcing

After the playbook completes, confirm the SELinux mode has changed on all nodes:

```bash
ansible all -m command -a "getenforce"
```
