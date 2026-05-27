# Use `ansible-navigator`

`ansible-navigator` is the official Red Hat tool for running Ansible content
inside an execution environment. It is the runner the EX294 exam uses, and
the lab is configured to mirror that: **`execution-environment: true`** with
the community EE image pre-pulled.

To make every role and collection the tasks depend on visible inside that
container, the lab pre-configures three things:

1. **Project auto-mount** — navigator always bind-mounts your project dir
   (the cwd containing the playbook). So anything under
   `~/ansible/mycollection/` and `~/ansible/roles/` is visible.
2. **System-roles bind-mount** — an explicit `volume-mounts` entry maps
   the host's `/usr/share/ansible/roles/` into the EE read-only, so the
   `rhel-system-roles` RPM is accessible by its standard name.
3. **`ansible.cfg`** — `collections_path = ./mycollection` and
   `roles_path = /usr/share/ansible/roles:./roles` so the engine searches
   all three locations once they're mounted.

See [Why the bind-mount?](#why-the-bind-mount) for the gory detail.

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

## Run a playbook (default — inside the EE)

```bash
ansible-navigator run ~/ansible/timesync.yml
```

What this does:

- Reads `~/.ansible-navigator.yml`, sees `execution-environment.enabled: true`.
- Spawns the `community-ansible-dev-tools` container under rootless `podman`.
- Auto-mounts the project directory (everything in `~/ansible/`) into the
  container, plus the explicit `/usr/share/ansible/roles:ro` bind-mount.
- Runs the playbook with the container's `ansible-core`.

`mode: stdout` is set in the config, so you get plain text instead of the
curses TUI. Pass `--mode interactive` to get the TUI back for any one run.

## Why the bind-mount?

The community EE image — `ghcr.io/ansible/community-ansible-dev-tools:latest`
— ships `ansible-core` and a few collections, but **not**
`rhel-system-roles`. Without help, EE-on runs of tasks 4 and 18 would fail
with:

```
ERROR! the role 'rhel-system-roles.timesync' was not found
```

There are three ways to fix that; the lab uses option (1):

1. **Bind-mount the host's RPM-installed roles into the EE** (what the lab
   does). The `volume-mounts` entry in `~/.ansible-navigator.yml` maps
   `/usr/share/ansible/roles → /usr/share/ansible/roles (ro)`. After that the
   EE's `roles_path` lookup finds `rhel-system-roles.timesync` exactly as if
   it were running on the host. We use `ro` not `:Z` because `student` can't
   relabel a system path under SELinux.
2. **Install the role into the project tree** —
   `ansible-galaxy role install linux-system-roles.timesync -p ./roles/`.
   `./roles/` is already auto-mounted by navigator, so the EE sees it. The
   role then resolves as `linux-system-roles.timesync` (the Galaxy alias).
3. **Use a Red Hat EE image that bundles the roles** —
   `registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9:latest`.
   Requires a Red Hat subscription and `podman login registry.redhat.io`. On
   the real EX294 exam this is what's used and the bind-mount is unnecessary;
   Red Hat additionally ships a `rhel-system-roles` collection tarball that
   the candidate installs into the project's `./mycollection/`.

`ansible.posix` (task 5, 11, 17) has the same EE-visibility problem and the
same project-local fix — except the lab solves it via option 2 only, since
it's lighter than a bind-mount: `ansible-galaxy collection install
ansible.posix -p ./mycollection` puts it under the auto-mounted project tree.

### `passlib` and the `password_hash` filter (task 14)

`ansible.builtin.password_hash` (used by task 14 to hash vault passwords
into `/etc/shadow`) needs the Python **`passlib`** library inside whichever
interpreter runs the play. The community EE doesn't ship it, so EE-on runs
of `create_user.yml` fail with:

```
The filter plugin 'ansible.builtin.password_hash' failed:
Unable to encrypt nor hash, passlib must be installed: No module named 'passlib'
```

The lab provisioner installs `python3-passlib` on the control node's host
Python (via dnf, with a pip fallback), so the workaround is to bypass the
container for that one task:

```bash
ansible-navigator run create_user.yml \
  --vault-password-file=./password.txt \
  --execution-environment false
```

The real EX294 EE (`ee-supported-rhel9`) bundles `passlib`, so the bypass
isn't needed on the exam. See [Answer 14](../../lab/solutions/answer-14.md)
for the full rationale.

## Run without the execution environment

When you want to debug a Python dependency on the host, or you just want
plain `ansible-playbook` behaviour without the container layer:

```bash
ansible-navigator run ~/ansible/timesync.yml --execution-environment false
```

This uses the host's `ansible-core` directly. Result is identical to
`ansible-playbook timesync.yml`. The bind-mount becomes a no-op (host already
has the roles) and SELinux/podman quirks disappear.

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

## Common runtime errors and fixes

### `The 'community.general.yaml' callback plugin has been removed`

Full message:

```
[ERROR]: The 'community.general.yaml' callback plugin has been removed.
The plugin has been superseded by the option `result_format=yaml` in
callback plugin ansible.builtin.default from ansible-core 2.13 onwards.
This feature was removed from collection 'community.general' version 12.0.0.
```

**Cause.** Your `ansible.cfg` (typically `/home/student/ansible/ansible.cfg`)
sets one of:

```ini
stdout_callback = yaml                       # short name -> community.general.yaml
stdout_callback = community.general.yaml     # explicit FQCN
```

Both resolve to a callback that no longer exists in
`community.general` 12.0.0+.

**Fix.** Use the built-in `default` callback with `result_format = yaml`:

```ini
[defaults]
stdout_callback = ansible.builtin.default
result_format   = yaml
```

You get the same YAML rendering with no dependency on `community.general`.
`result_format = yaml` has been available since `ansible-core` 2.13. To
locate every config that still has the old setting:

```bash
grep -RIn "community.general.yaml\|stdout_callback\s*=\s*yaml" \
  /etc/ansible/ ~/ansible/ ~/.ansible.cfg 2>/dev/null
```

See [Answer 1 — `ansible.cfg`](../../lab/solutions/answer-01.md) for the
full reference config, and [Known task discrepancies → Task 1](../explanation/known-task-discrepancies.md#task-1--stdout_callback--yaml-now-uses-the-built-in-callback)
for the rationale.

### `No module named 'ansible_collections.redhat'` (tasks 4 & 18)

Full message (with the role tasks line varying by which role you ran):

```
[WARNING]: Error loading plugin 'redhat.rhel_system_roles.sefcontext':
No module named 'ansible_collections.redhat'
[ERROR]: couldn't resolve module/action 'redhat.rhel_system_roles.sefcontext'.
This often indicates a misspelling, missing collection, or incorrect module path.
Origin: /usr/share/ansible/roles/rhel-system-roles.selinux/tasks/main.yml:129:3
```

**Cause.** `rhel-system-roles` 2.x+ (current on RHEL/AlmaLinux 9.5+)
moved the actual modules into a bundled collection at
`/usr/share/ansible/collections/ansible_collections/redhat/rhel_system_roles/`.
The legacy role directory at `/usr/share/ansible/roles/rhel-system-roles.X/`
now just orchestrates calls into that collection via FQCN. If
`ansible-core` (host or EE) can't see the collection on its search path,
the role loads but its first task fails.

**Fix — host runs (`ansible-playbook`).** Extend `collections_path` in
`/home/student/ansible/ansible.cfg` to include the system path:

```ini
[defaults]
collections_path = ./mycollection:/usr/share/ansible/collections:~/.ansible/collections
```

`collections_path` **replaces** ansible's default search path, so
listing only `./mycollection` hides the RPM-installed collection.

**Fix — navigator + EE runs (`ansible-navigator run`).** Bind-mount
the host's collections directory into the EE container, same shape as
the existing roles mount. In `/home/student/.ansible-navigator.yml`:

```yaml
ansible-navigator:
  execution-environment:
    volume-mounts:
      - src: /usr/share/ansible/roles
        dest: /usr/share/ansible/roles
        options: ro
      - src: /usr/share/ansible/collections
        dest: /usr/share/ansible/collections
        options: ro
```

(The lab's `scripts/control/setup-control.sh` writes this version of
the file on fresh provisioning. If you provisioned before the fix
landed, edit the file in place and re-run.)

See [Answer 1](../../lab/solutions/answer-01.md) for the canonical
configs and [Known task discrepancies → Tasks 4 & 18](../explanation/known-task-discrepancies.md#tasks-4--18--rhel-system-roles-2x-needs-the-bundled-collection-on-the-search-path)
for the full rationale.

## Related

- [Work around the pip-ansible "Illegal instruction" crash](work-around-ansible-illegal-instruction.md) — why the lab prefers the distro `ansible` on `PATH` over `pip --user`.
- [Explanation: `ansible-navigator` install paths](../explanation/ansible-navigator-install.md).
- [Task 1 — Install and Configure Ansible](../../lab/tasks/task-01.md) — where ansible-navigator first gets installed and configured.
- [Answer 1](../../lab/solutions/answer-01.md) — the `~/.ansible-navigator.yml` reference config.
