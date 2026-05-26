# Use `ansible-navigator`

`ansible-navigator` is the official Red Hat tool for running Ansible content
in an execution environment. It is the tool used in the EX294 exam.

The lab installs `ansible-navigator` on the control node and pre-pulls the
community execution environment image
(`ghcr.io/ansible/community-ansible-dev-tools:latest`).

## Confirm it works

```bash
vagrant ssh control
sudo -iu student
ansible-navigator --version
```

Example output:

```
ansible-navigator 25.5.0
```

Exact patch numbers drift over time; the lab installs whatever the
current AAP/EPEL/pip channel provides. If you need to know which
install path was used on your host, see
[`ansible-navigator` install paths](../explanation/ansible-navigator-install.md).

## Run a playbook in EE mode (recommended)

```bash
ansible-navigator run ~/ansible/task-01.yml --mode stdout
```

What this does:

- Spawns the `community-ansible-dev-tools` container.
- Mounts your home directory into the container.
- Runs the playbook with the container's `ansible-core`.

Drop the `--mode stdout` to get the full TUI (text user interface) instead of
plain text output.

## Run without the execution environment

When you do not want a container — for example you are debugging a Python
dependency on the host:

```bash
ansible-navigator run ~/ansible/task-01.yml --execution-environment false --mode stdout
```

This uses the **host's** `ansible-core` (the one installed by `dnf` — on
aarch64 often `/usr/local/bin/ansible`, otherwise `/usr/bin/ansible`). It is
the same engine that `ansible-playbook` uses, so the result is identical to
running `ansible-playbook` directly.

## Look up plugin documentation and examples

The exam has no internet. `ansible-navigator doc` is the offline
equivalent of [docs.ansible.com](https://docs.ansible.com) — it pulls
the docs straight from the plugin's source, so you see exactly the
parameters and `EXAMPLES:` block that match the version running inside
your EE.

### Show full docs for a plugin

```bash
ansible-navigator doc ansible.builtin.yum_repository --mode stdout
```

Output is the same five sections you'd see online:

- `ADDED_IN` — when the module landed.
- `DESCRIPTION` — what it does.
- `OPTIONS` — every parameter, its type, default, choices.
- `EXAMPLES` — copy-paste-ready snippets.
- `RETURN` — keys you can `register:` and reference.

Drop `--mode stdout` to launch the TUI; navigate with the arrow keys
and press `:doc <name>` to jump between plugins, `:back` to return,
`:quit` to exit.

### Jump straight to `EXAMPLES` (exam workflow)

When you remember the module's name but not its exact YAML, you only
want the examples. Pipe through `sed`:

```bash
ansible-navigator doc ansible.builtin.yum_repository --mode stdout \
  | sed -n '/^EXAMPLES:/,/^RETURN/p'
```

Or — since the EE doesn't always reach `ansible-doc -s` — use the
short-form synopsis to get a one-paragraph parameter cheatsheet:

```bash
ansible-navigator doc -s ansible.builtin.cron --mode stdout
```

### List every plugin available in the EE

```bash
ansible-navigator doc -l --mode stdout
```

Pipe through `grep` to find a module by keyword. The exam often phrases
a task without naming the module — this is how you find it:

```bash
# "configure a cron job"
ansible-navigator doc -l --mode stdout | grep -i cron

# "open a firewall port"
ansible-navigator doc -l --mode stdout | grep -i firewall

# "manage an LVM volume"
ansible-navigator doc -l --mode stdout | grep -iE 'lvm|lvol|lvg'
```

### Filter by plugin type

`-t` (or `--type`) narrows the listing to a plugin category. Useful
for `lookup`, `filter`, `become`, and the rest:

```bash
ansible-navigator doc -l -t lookup --mode stdout      # lookup plugins
ansible-navigator doc -l -t filter --mode stdout      # jinja2 filters
ansible-navigator doc -l -t become --mode stdout      # privilege-escalation
ansible-navigator doc -t lookup ansible.builtin.file --mode stdout
```

### Browse collections

`collections` shows every collection bundled into the EE, with the
modules / roles / plugins each one provides. Great for "I know the
collection but not the exact module name":

```bash
ansible-navigator collections --mode stdout

# Drill into one collection (TUI is more useful here than stdout)
ansible-navigator collections
# then arrow into community.general, then arrow into a plugin
```

### Look up a role

`--type role` works on some `ansible-navigator` versions, but is
patchy across releases. The reliable lookup is to read the role's
`README.md` directly:

```bash
# Galaxy-installed (per task 18)
cat ~/ansible/roles/linux-system-roles.selinux/README.md

# RPM-installed (rhel-system-roles package)
cat /usr/share/ansible/roles/rhel-system-roles.selinux/README.md
```

### Tip — bookmark these for the 18 lab tasks

| Task  | Plugin                                            | Why |
|-------|---------------------------------------------------|-----|
| 2     | `ansible.builtin.yum_repository`                  | dnf repo files |
| 3     | `ansible.builtin.dnf`                             | install/update packages |
| 5–9   | `ansible.builtin.user`, `.group`                  | accounts, sudo |
| 10    | `ansible.builtin.cron`                            | scheduled jobs |
| 11    | `ansible.posix.firewalld`                         | open ports/services |
| 12    | `ansible.builtin.template`                        | Jinja2 → file |
| 13    | `ansible.builtin.lineinfile`                      | edit a single line |
| 14    | `ansible.builtin.copy` + Vault                    | secrets |
| 16    | `community.general.lvol`                          | logical volumes |
| 17    | `community.general.parted`, `ansible.posix.mount` | partitions + fstab |
| 18    | `linux-system-roles.selinux` (role)               | SELinux mode |

## Inspect the EE image

```bash
podman images | grep dev-tools
podman run --rm ghcr.io/ansible/community-ansible-dev-tools:latest \
       ansible --version
```

## Use a different EE image

Edit `/home/student/.ansible-navigator.yml`:

```yaml
---
ansible-navigator:
  execution-environment:
    enabled: true
    image: registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9:latest
    pull:
      policy: missing
    container-engine: podman
```

For Red Hat's official EE images you need a Red Hat subscription and to
`podman login registry.redhat.io` first. See [Use RHEL with subscription](use-rhel-with-subscription.md).

## Common warnings to ignore

These appear under `podman` running as `student` and are harmless:

```
WARN: The cgroupv2 manager is set to systemd but there is no systemd user session available
WARN: Falling back to --cgroup-manager=cgroupfs
```

If you want them gone, enable lingering for the student user:

```bash
sudo loginctl enable-linger student
```

## Related

- [Work around the pip-ansible "Illegal instruction" crash](work-around-ansible-illegal-instruction.md) — why we recommend EE mode or the distro `ansible` on `PATH`.
- [Explanation: `ansible-navigator` install paths](../explanation/ansible-navigator-install.md).
- [Task 1 — Install and Configure Ansible](../../lab/tasks/task-01.md) — where ansible-navigator first gets installed and configured.
- [Answer 1](../../lab/solutions/answer-01.md) — the `~/.ansible-navigator.yml` reference config.
