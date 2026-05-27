## Task 18 — SELinux role: permissive then enforcing (via `ansible-navigator`)

### What this teaches

- **The selinux role's "I need a reboot" failure pattern.** When the
  role transitions to/from `disabled`, it sets the fact
  `selinux_reboot_required: true` and **fails on purpose** so the
  playbook stops and you handle the reboot explicitly. The canonical
  response is the **block / rescue + reboot + re-include the role**
  pattern below.
- **`include_role:`** (dynamic) vs `roles:` (static). Dynamic includes
  can be wrapped in block/rescue; the static `roles:` keyword cannot.
- **`ansible-navigator run`** as a drop-in replacement for
  `ansible-playbook`, executing inside an execution-environment
  container. The lab's `~/.ansible-navigator.yml` (laid down by
  `scripts/control/setup-control.sh`) pre-configures the EE image.

### Prerequisite — install the role

The lab pre-installs the `rhel-system-roles` RPM and the navigator
config bind-mounts both `/usr/share/ansible/roles` and
`/usr/share/ansible/collections` into the EE, so the role at
`/usr/share/ansible/roles/rhel-system-roles.selinux` **and** the
bundled `redhat.rhel_system_roles` collection it calls internally are
both reachable. If you ever need to rebuild it:

```bash
sudo dnf install -y rhel-system-roles
```

> **Why the second mount.** Starting with `rhel-system-roles` 2.x, the
> selinux role's `tasks/main.yml` references
> `redhat.rhel_system_roles.sefcontext` and friends from a private
> collection the RPM ships at
> `/usr/share/ansible/collections/ansible_collections/redhat/rhel_system_roles/`.
> Without that path on `collections_path` (host runs) or bind-mounted
> into the EE (navigator runs), the role loads but the first task fails
> with *No module named 'ansible_collections.redhat'*. The lab's
> `ansible.cfg` extends `collections_path` and
> `~/.ansible-navigator.yml` adds the bind-mount to cover both runners
> — see [Answer 1](answer-01.md) for the exact configs and
> [Known task discrepancies → Tasks 4 & 18](../../docs/explanation/known-task-discrepancies.md#tasks-4--18--rhel-system-roles-2x-needs-the-bundled-collection-on-the-search-path).

Galaxy fallback (works without the RPM; resolves as
`linux-system-roles.selinux`):

```bash
ansible-galaxy role install linux-system-roles.selinux -p ./roles/
```

### `selinux.yml` — flip to permissive

```yaml
- name: Set SELinux mode to permissive
  hosts: all
  become: true
  vars:
    selinux_state: permissive

  tasks:
    - name: Apply the selinux role; reboot only if it says so
      block:
        - name: First pass
          ansible.builtin.include_role:
            name: rhel-system-roles.selinux
      rescue:
        - name: Bail out if the failure was something other than reboot
          ansible.builtin.fail:
            msg: "selinux role failed for a non-reboot reason"
          when: not (selinux_reboot_required | default(false))

        - name: Reboot to actualize SELinux mode change
          ansible.builtin.reboot:
            msg: "Rebooting for SELinux mode change"
            reboot_timeout: 600

        - name: Re-apply selinux role after reboot
          ansible.builtin.include_role:
            name: rhel-system-roles.selinux
```

### `selinux2.yml` — flip to enforcing

Same shape, one variable changed:

```yaml
- name: Set SELinux mode to enforcing
  hosts: all
  become: true
  vars:
    selinux_state: enforcing

  tasks:
    - name: Apply the selinux role; reboot only if it says so
      block:
        - name: First pass
          ansible.builtin.include_role:
            name: rhel-system-roles.selinux
      rescue:
        - name: Bail out if the failure was something other than reboot
          ansible.builtin.fail:
            msg: "selinux role failed for a non-reboot reason"
          when: not (selinux_reboot_required | default(false))

        - name: Reboot to actualize SELinux mode change
          ansible.builtin.reboot:
            msg: "Rebooting for SELinux mode change"
            reboot_timeout: 600

        - name: Re-apply selinux role after reboot
          ansible.builtin.include_role:
            name: rhel-system-roles.selinux
```

(Real-life pattern: extract that `tasks:` block into a tiny wrapper
role so `selinux.yml` and `selinux2.yml` just include it with
different `selinux_state`. Kept inline here so the solution is one
copy-paste per file.)

### Run

```bash
# Task spec is explicit about which runner per file:
ansible-playbook selinux.yml
ansible-navigator run selinux2.yml --mode stdout

# Either runner works for either file — these also pass:
ansible-navigator run selinux.yml  --mode stdout
ansible-playbook       selinux2.yml
```

The `--mode stdout` flag (short form `-m stdout`) tells
`ansible-navigator` to print the play recap directly instead of
launching the curses TUI — essential for a graded environment.

### Verify

```bash
# Runtime state
ansible all -b -a 'getenforce'
# Enforcing

# Persistent state — what /etc/selinux/config says is what survives reboot
ansible all -b -a 'grep ^SELINUX= /etc/selinux/config'
# SELINUX=enforcing
```

### Best-practice notes

- **Check `/etc/selinux/config`, not just `getenforce`.** A bare
  `setenforce 0` would make `getenforce` say "Permissive" but the file
  would still say "enforcing" — the change wouldn't survive reboot.
  The role updates both; that's the whole point.
- **`reboot_timeout: 600`** is a defensive ceiling — `reboot` waits
  for the host to come back, so a 10-minute window covers slow VMs.
  Default is 600 already; declaring it makes intent explicit.
- **`include_role:` vs `roles:` matters.** `roles:` runs statically
  *before* `tasks:`, so you cannot wrap it in `block:`. `include_role:`
  runs in task order and supports rescue/always. For any role that
  might need to reboot, use `include_role:`.
- **The role is documented at
  [github.com/linux-system-roles/selinux](https://github.com/linux-system-roles/selinux)**
  for the full variable list (`selinux_booleans`, `selinux_fcontexts`,
  `selinux_ports`, …). For the exam we only need `selinux_state`.
- **AlmaLinux 9 boots in `enforcing` by default.** Flipping to
  `permissive` and back to `enforcing` doesn't actually require a
  reboot — the role only forces one when the transition crosses the
  `disabled` boundary. The rescue branch is therefore *latent* here
  but correct, and would save points the moment SELinux ever starts
  disabled.
