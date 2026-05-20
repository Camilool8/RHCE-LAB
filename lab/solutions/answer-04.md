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

**B — via Galaxy** (works without the package; needs internet):

```bash
ansible-galaxy role install linux-system-roles.timesync -p ./roles/
```

The reference solution uses option B so the role lives under
`./roles/` next to the play.

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
    - role: linux-system-roles.timesync
```

### Run

```bash
ansible-playbook timesync.yml
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
- **`linux-system-roles.timesync` is an alias** for what RHEL 9 ships
  as `rhel-system-roles.timesync`. Both resolve to the same role
  source. The "linux" form is the portable name; pick it for content
  you intend to share outside RHEL.
- The variable used to be `timesync_ntp_servers`; on RHEL 10 / AAP 2.5
  the role uses the same name. No migration needed.
