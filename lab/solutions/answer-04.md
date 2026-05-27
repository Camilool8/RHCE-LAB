## Task 4 — `timesync` system role against `172.25.254.250`

### What this teaches

- **RHEL System Roles** are an officially supported set of Ansible
  roles maintained by Red Hat for common admin tasks (time sync,
  SELinux, firewall, storage, …). They live in the
  `rhel-system-roles` RPM on RHEL/AlmaLinux 9, and are mirrored to
  Galaxy under the `linux-system-roles.*` namespace.
- The `timesync` role abstracts whatever the OS uses for time sync
  (chrony on RHEL 9). You declare *what* you want; the role
  picks the *how*.
- Variables (`timesync_ntp_servers`, `timesync_step_threshold`) are the
  documented role API — read them, don't grep the role's tasks.

### Two ways to get the role

**A — via RPM** (recommended; no internet needed if the lab repos
are healthy):

```bash
sudo dnf install -y rhel-system-roles
# Roles land in /usr/share/ansible/roles/, e.g.
#   /usr/share/ansible/roles/rhel-system-roles.timesync
```

The lab pre-installs this RPM and `~/.ansible-navigator.yml` bind-mounts
**both** `/usr/share/ansible/roles → /usr/share/ansible/roles (ro)` and
`/usr/share/ansible/collections → /usr/share/ansible/collections (ro)`
into the EE, so the role is visible by its `rhel-system-roles.timesync`
name and the `redhat.rhel_system_roles` collection it now internally
calls into is also reachable from inside `ansible-navigator run`. The
matching `collections_path = ./mycollection:/usr/share/ansible/collections:~/.ansible/collections`
in `ansible.cfg` is what makes the same role work under host-side
`ansible-playbook`. Without that path extension, you get
*No module named 'ansible_collections.redhat'*. See
[Use ansible-navigator → Why the bind-mount?](../../docs/how-to/use-ansible-navigator.md#why-the-bind-mount)
for the mechanism and
[Known task discrepancies → Tasks 4 & 18](../../docs/explanation/known-task-discrepancies.md#tasks-4--18--rhel-system-roles-2x-needs-the-bundled-collection-on-the-search-path)
for the full rationale.

**B — via Galaxy** (works without the RPM; needs internet):

```bash
ansible-galaxy role install linux-system-roles.timesync -p ./roles/
```

This drops the role under the project's `./roles/` — auto-mounted by
navigator — and you'd then reference it as `linux-system-roles.timesync`.
Use this path if the lab repos are unreachable.

### `timesync.yml`

```yaml
- name: Configure NTP across the fleet via the timesync system role
  hosts: all
  become: true

  vars:
    timesync_ntp_servers:
      - hostname: 172.25.254.250
        iburst: true

  roles:
    - role: rhel-system-roles.timesync
```

### Run

```bash
ansible-playbook timesync.yml
# or, with the exam runner:
ansible-navigator run timesync.yml --mode stdout
```

### Verify

```bash
ansible all -b -m shell -a 'grep -E "^(server|pool) 172" /etc/chrony.conf'
ansible all -b -a 'systemctl is-active chronyd'
ansible all -b -a 'chronyc -n sources'
```

### Best-practice notes

- **`iburst: true`** is the documented way to ask chrony for fast
  initial sync. Don't try to set it via a templated `chrony.conf` line
  — the role manages that file and will overwrite your edits.
- **`hosts: all`**, not `hosts: managed`. Time sync belongs on every
  node, including any future ones added to the inventory.
- **`rhel-system-roles.timesync` and `linux-system-roles.timesync`** are
  aliases — both directories ship in the `rhel-system-roles` RPM and
  point at the same role source. The "rhel" form matches the task wording
  ("the role provided by `rhel-system-roles`"); the "linux" form is the
  portable name you'd use for content shared outside RHEL.
- The variable used to be `timesync_ntp_servers`; on RHEL 10 / AAP 2.5
  the role uses the same name. No migration needed.
