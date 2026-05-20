# Known task discrepancies (and what we fixed)

This page documents every place the lab's tasks, reference solutions,
and provisioned machine state used to disagree — and what was done
about it. The goal is to teach RHCE-grade practice, not memorization,
so the lab content has been edited to **prefer best practice over
faithfulness to a brittle exam transcript**.

The discrepancies are in three buckets:

1. **Fixed** — task text and/or reference solution rewritten.
2. **By design** — the task wants the student to discover/install
   something themselves. Documented so it's not surprising.
3. **Remaining external dependencies** — things outside the lab's
   control.

## Fixed

### Task 8 — symlink direction was reversed

The task says "Symbolically link `/var/www/html/webtest` to `/webtest`."
The natural reading (and what the verifier checks) is that
`/var/www/html/webtest` is the link and `/webtest` is the target.

The original reference solution put it the other way, which would
clobber the setgid directory it had just created. The updated solution
makes the symlink direction explicit and the comment in `answer-08.md`
calls out why.

### Task 14 — `password_hash('sha512')` was non-idempotent

Without an explicit salt, the filter generates a fresh random salt on
every run, so the resulting hash changes and the `user` module rewrites
the password. The exam grader applies playbooks against fresh systems
and re-runs them; non-idempotency costs real points.

**Fix** (in `lab/solutions/answer-14.md`):

```yaml
vars:
  pwd_salt: rh294salt
…
password: "{{ dev_pass | password_hash('sha512', pwd_salt) }}"
update_password: on_create
```

Explicit salt → deterministic hash → idempotent re-runs.
`update_password: on_create` is a belt-and-suspenders second guard.

The verifier (`scripts/verify/tasks/task-14.sh`) now enforces strict
idempotency on this task — the previous tolerance was removed.

### Task 17 — hard-coded `/dev/sdb` broke libvirt and VMware

Both the task text and the reference solution literally said
`/dev/sdb`. AlmaLinux 9 boots `/dev/sda` on VirtualBox/Parallels,
`/dev/vda` on libvirt, `/dev/nvme0n1` on VMware — so the original
reference solution didn't run on two of the four providers.

**Fix** (in `lab/tasks/task-17.txt` and `lab/solutions/answer-17.md`):

- Task text now says "the additional raw data disk" and explicitly
  forbids hard-coding the device name. It also adds the hint that
  `ansible_facts.devices` is the right place to look.
- The reference solution uses an `ansible_facts.devices`-driven
  `set_fact` to derive the disk path at runtime, and handles the
  `nvme0n1p1` vs `sdb1` partition-naming difference too.
- `docs/reference/storage-layout.md` keeps the per-provider table as a
  debugging reference.

### Task 18 — SELinux role's reboot requirement was unhandled

When the `linux-system-roles.selinux` role crosses the
`disabled` boundary it sets `selinux_reboot_required: true` and
**fails on purpose**. The original reference solution lacked the
`block / rescue + reboot + re-include_role` pattern that's expected
when consuming this role, so the first run would fail.

**Fix** (in `lab/solutions/answer-18.md`): both `selinux.yml` and
`selinux2.yml` now wrap `include_role:` in a `block:` whose `rescue:`
checks `selinux_reboot_required`, reboots if needed, and re-applies
the role. The explanation in the answer file calls out why
`include_role:` (dynamic) is required for this pattern instead of
`roles:` (static).

### Task 16 — rescue branch is now actually exercised

The VG `research` used to be 2 GiB, so the task's 1200 MiB primary
size always fit and the `rescue:` fallback to 800 MiB was dead code.
`config.yaml` now sizes extra disk 2 to 1 GiB on purpose so 1200 MiB
fails and the rescue branch fires every run. That's how a student
knows their rescue logic actually works — not just that it parses.

### Offline mirror replaces the ISO drop

The previous design copied packages from a user-supplied DVD ISO. If
no ISO was present, the lab silently fell back to AlmaLinux's online
mirrors and several tasks needed live internet during practice.

**Fix:** `scripts/repo-server/setup-repos.sh` now `dnf reposync`s the
upstream BaseOS and AppStream during repo-server provisioning (the
*only* moment internet is required). Every managed node points dnf
at the lab mirror via `/etc/yum.repos.d/lab-offline.repo` and disables
the vendor online repos.

See [`docs/explanation/offline-mirror.md`](offline-mirror.md) for the
full design rationale.

### Best-practice sweep across all 18 solutions

Every answer file gained a "What this teaches" section and best-practice
notes. Concrete deltas worth knowing:

- **All modules use FQCN** (`ansible.builtin.copy`, not just `copy`).
  Required for ansible-navigator execution environments;
  recommended everywhere.
- **`state: present` vs `state: latest`** is now used deliberately —
  `latest` only on the "update all packages" task that explicitly
  asks for upgrades.
- **`ansible_facts.lvm` / `ansible_facts.devices`** (the namespaced
  forms) instead of `ansible_lvm` / `ansible_devices` (the bare forms
  deprecated in ansible-core 2.10).
- **`copy: content:` writes explicit `\n`** to avoid trailing-newline
  idempotency drift.
- **`defaults/main.yml`** for role variables (overridable) instead of
  `vars/main.yml` (not overridable from outside the role).
- **`handlers/`** added to the apache role so service reloads on
  template changes are explicit rather than implicit-from-restart.

## By design — not bugs

### Task 4 — student installs the system-roles package

The task literally says "Install the RHEL system roles package." The
provisioner stops at `ansible-core`; the student is expected to
`sudo dnf install rhel-system-roles` (now serves from the lab mirror)
or `ansible-galaxy role install linux-system-roles.timesync -p ./roles/`
(needs internet for Galaxy).

### Task 15 — `natasha` not pre-created

The cron job runs as user `natasha`, who is not provisioned by
`scripts/common/create-users.sh`. The reference solution correctly
creates her in the same playbook before the cron task. This is the
expected pattern — the grader checks that the user exists *as a side
effect* of the playbook running.

## Remaining external dependencies

### Galaxy URLs in task 6

Three legacy `galaxy.ansible.com/download/*.tar.gz` URLs are still
served as of 2026-05-20 (302 → S3 → 200). The `mafalb.squid` role's
namespace listing dropped the role but the artifact persists. If
that ever 404s, `geerlingguy.squid` is the recommended drop-in.

### EE image pull (task 18 with ansible-navigator)

`ghcr.io/ansible/community-ansible-dev-tools:latest` is pulled by
`scripts/control/setup-control.sh` during initial provisioning and
needs internet at that moment. After that, the image is cached on
the control node.

## Related

- [`scripts/verify/README.md`](../../scripts/verify/README.md) — the
  verifier that emulates the EX294 grader against the updated solutions.
- [`docs/explanation/offline-mirror.md`](offline-mirror.md) — how the
  lab works without an ISO.
- [`docs/reference/storage-layout.md`](../reference/storage-layout.md) —
  per-provider device names and the asymmetric disk sizing.
- [`docs/reference/tasks.md`](../reference/tasks.md) — task summary.
