## Task 1 — Inventory and `ansible.cfg`

### What this teaches

- How to install **`ansible-core` and `ansible-navigator`** on a
  RHEL/AlmaLinux 9 control node — both are what the exam expects you to
  type even if the practice lab pre-installs them for you.
- How to wire `~/.ansible-navigator.yml` so every later task can run
  with `ansible-navigator run <playbook>.yml --mode stdout` (the
  exam-realistic runner).
- How to look up plugin documentation and **copy/paste working
  examples** offline with `ansible-navigator doc` — the single most
  useful skill for the exam, where you have no internet.
- The static-INI inventory format and group hierarchy
  (`[webservers:children]` makes `webservers` a parent of `prod`).
- The exact `ansible.cfg` knobs that make `ansible all -m ping`
  Just Work from `/home/student/ansible/` with no extra flags — the
  EX294 grader assumes this.
- Pre-wiring `vault_password_file` so playbooks that read encrypted
  variables (task 14) need no `--vault-password-file` argument.

### Install Ansible + ansible-navigator on the control node

On a fresh RHEL/AlmaLinux 9 control node (this is the step the exam
expects in part (a)):

```bash
sudo dnf install -y ansible-core
sudo dnf install -y ansible-navigator   # from AAP repo on RHEL, EPEL on AlmaLinux
```

Confirm both:

```bash
$ ansible --version
ansible [core 2.16.x]
  python version = 3.11.x

$ ansible-navigator --version
ansible-navigator 25.5.0
```

Exact patch versions drift — the major/minor is what matters. On the
lab the EPEL/pip path installs **`ansible-navigator 25.5.0` or newer**;
on a real RHEL 9 + AAP 2.5 box you get whatever Red Hat ships in that
channel. See
[`ansible-navigator` install paths](../../docs/explanation/ansible-navigator-install.md)
for which path each host takes.

> **In this lab** both `ansible-core` and `ansible-navigator` are
> already installed by `scripts/control/setup-control.sh` during
> `vagrant up`, so you do not need to run the commands above to make
> the verifier pass. They are shown here because the EX294 task expects
> the student to know them. See
> [Known task discrepancies](../../docs/explanation/known-task-discrepancies.md).

### `~/.ansible-navigator.yml`

The lab drops this file at `/home/student/.ansible-navigator.yml`. If
you ever need to rebuild it (or on the exam, write it from scratch):

```yaml
---
ansible-navigator:
  execution-environment:
    enabled: true
    image: ghcr.io/ansible/community-ansible-dev-tools:latest
    pull:
      policy: missing
    container-engine: podman
  mode: stdout
  playbook-artifact:
    enable: false
```

Why each key:

- **`enabled: true`** — run the playbook inside the EE container, the
  way the exam grader does. Use `false` only when you want to debug a
  host-side Python issue.
- **`image:`** — the community EE image the lab pre-pulls. No
  `podman login` needed (unlike `registry.redhat.io/.../ee-supported-rhel9`).
- **`pull.policy: missing`** — only pull when the image is absent.
  Keeps you offline-friendly after the first run.
- **`mode: stdout`** — default to plain text instead of the curses
  TUI. Saves typing `--mode stdout` on every command.
- **`playbook-artifact.enable: false`** — don't write a
  `playbook-artifact-*.json` next to every run.

### `inventory`

```ini
[dev]
node1

[test]
node2

[prod]
node3
node4

[balancers]
node5

[webservers:children]
prod
```

### `ansible.cfg`

```ini
[defaults]
inventory            = ./inventory
roles_path           = ./roles
collections_path     = ./mycollection
remote_user          = student
private_key_file     = ~/.ssh/RH294-LAB
host_key_checking    = False
vault_password_file  = ./password.txt
nocows               = True
stdout_callback      = yaml
deprecation_warnings = False
retry_files_enabled  = False
forks                = 10
```

### Run

```bash
ansible all -m ping
ansible-inventory --graph
```

`ansible-inventory --graph` should print the group tree with `prod`
nested under `webservers`.

### Look up plugin docs and examples — your exam offline reference

Every later task in this lab uses one or two modules you'll want to
crib syntax from. On the exam you have **no internet**, but
`ansible-navigator doc` is the offline equivalent of
[docs.ansible.com](https://docs.ansible.com) — and it ships with the
EE image, so it never lags behind the modules you actually run.

```bash
# Show full docs (synopsis + parameters + EXAMPLES + return values)
ansible-navigator doc ansible.builtin.yum_repository --mode stdout

# Jump straight to the EXAMPLES section — exam workflow
ansible-navigator doc ansible.builtin.yum_repository --mode stdout \
  | sed -n '/^EXAMPLES:/,/^RETURN/p'

# List every plugin the EE knows about
ansible-navigator doc -l --mode stdout

# Filter the list — "what dnf-related modules do I have?"
ansible-navigator doc -l --mode stdout | grep -i dnf

# Browse collections interactively (drop --mode stdout for the TUI)
ansible-navigator collections
ansible-navigator collections --mode stdout
```

Try it now on a module you'll need in task 2:

```bash
ansible-navigator doc ansible.builtin.yum_repository --mode stdout
```

You'll see the same `EXAMPLES:` block that's on docs.ansible.com —
copy-paste the snippet that matches your task, edit the values, done.

A handful of plugins worth bookmarking for the 18 tasks:

| Task | Plugin | Why |
|------|--------|-----|
| 2    | `ansible.builtin.yum_repository`     | dnf repo files |
| 3    | `ansible.builtin.dnf`                | install/update packages |
| 5–9  | `ansible.builtin.user`, `.group`     | accounts, sudo |
| 10   | `ansible.builtin.cron`               | scheduled jobs |
| 11   | `ansible.posix.firewalld`            | open ports/services |
| 12   | `ansible.builtin.template`           | Jinja2 → file |
| 13   | `ansible.builtin.lineinfile`         | edit a single line |
| 14   | `ansible.builtin.copy` + Vault       | secrets |
| 16   | `community.general.lvol`             | logical volumes |
| 17   | `community.general.parted`, `ansible.posix.mount` | partitions + fstab |
| 18   | `linux-system-roles.selinux` (role)  | SELinux mode |

For roles, `ansible-navigator doc --type role <name>` exists but is
patchy across versions — `cat
~/roles/<role>/README.md` (or `/usr/share/ansible/roles/<role>/README.md`
for RPM-installed roles) is the reliable lookup.

More detail and the TUI workflow: [Use ansible-navigator → Look up
plugin documentation and
examples](../../docs/how-to/use-ansible-navigator.md#look-up-plugin-documentation-and-examples).

### Best-practice notes

- **`vault_password_file = ./password.txt`** turns
  `ansible-playbook create_user.yml` into a one-liner. Task 14's
  reference solution then doesn't need to pass `--vault-password-file`
  every time — the grader runs the same shorthand.
- **`stdout_callback = yaml`** makes module output human-readable
  during practice. Switch to `json` in CI.
- **`forks = 10`** parallelizes across the 5 managed nodes (default
  is 5 — fine, but 10 leaves headroom).
- The cfg lives at **`./ansible.cfg`** (current directory) so it only
  takes effect when running from `/home/student/ansible/`. That's
  intentional — a system-wide `/etc/ansible/ansible.cfg` would leak
  into unrelated work.
