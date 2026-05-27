# RHCE-LAB task verifier

A local emulator of the Red Hat EX294 score-calculator. Iterates the 18
practice tasks in `lab/tasks/`, checks the resulting state on every managed
node, and prints a 300-point scorecard with the standard 210/300 = 70 %
passing line.

## What it does

For each task:

1. **(optional) `--apply`** — re-runs the student's playbook **twice** and
   captures a failure if the second run produces `changed=[1-9]` or
   `failed=[1-9]`. That's the published idempotency convention used by
   Molecule and described in the Red Hat course material.
2. **`task_verify`** — SSHes into the relevant managed nodes and checks
   end state (files, packages, services, firewall, mounts, SELinux mode,
   crontab, vault decryption, etc.).
3. **(optional) `--reboot`** — reboots all 5 nodes, waits for SSH, and
   re-runs `task_verify` (or `task_reboot_survival` if defined). This is
   the same persistence check the EX294 grader performs against fresh
   systems — fstab, systemctl is-enabled, `/etc/selinux/config`, /etc/cron.d
   entries, etc., must all survive.

The total max is 300; the script exits 0 iff the score >= `PASS_THRESHOLD`
(default 210).

## Where it runs

On the **control node** (`ansible-control`), as the **student** user.
The script `cd`s into `$ANSIBLE_DIR` (default `/home/student/ansible`)
before invoking Ansible, then SSHes into each managed node via
`/home/student/.ssh/RH294-LAB`. Bash 4+ required (AlmaLinux 9 ships 5.x).

The Vagrantfile copies `scripts/verify/` to `/home/student/verify/` on
the control node during provisioning (owned by `student`, with the
`.sh` files executable). Editing any verifier file on the host and
running `vagrant provision control` re-syncs the latest copy.

## Usage

All commands below run on the control node as the `student` user.

```bash
# State-only audit (fast, non-mutating)
~/verify/verify-all.sh

# Also re-run every playbook (twice) for idempotency
~/verify/verify-all.sh --apply

# Re-verify after a full reboot pass
~/verify/verify-all.sh --apply --reboot

# Single task or a subset
~/verify/verify-all.sh --task 16
~/verify/verify-all.sh --task 1,5,18

# Print the task table (point allocation)
~/verify/verify-all.sh --list
```

## Environment overrides

| Variable             | Default                       | Use for                              |
| -------------------- | ----------------------------- | ------------------------------------ |
| `ANSIBLE_DIR`        | `/home/student/ansible`       | running the verifier from elsewhere  |
| `SSH_USER`           | `student`                     | testing as `redhat`                  |
| `SSH_KEY`            | `/home/student/.ssh/RH294-LAB`| alternate key                        |
| `PASS_THRESHOLD`     | `210`                         | local pass mark (out of 300)         |
| `TIME_SERVER`        | `172.25.254.250`              | task 4 ntp server                    |
| `VAULT_PW_INITIAL`   | `rh294lab`                    | task 9 starting vault password       |
| `VAULT_PW_REKEYED`   | `ansible`                     | task 13 post-rekey vault password    |
| `REBOOT_WAIT_SECS`   | `600`                         | per-node ceiling on the post-reboot SSH-up wait (`--reboot`). Bump on slow hypervisors. |
| `REBOOT_DOWN_SECS`   | `30`                          | per-node ceiling on the "wait for SSH to drop" phase. Bump if a playbook just rebooted nodes and reboots are stacking. |
| `NO_COLOR=1`         | (unset)                       | strip ANSI escapes for CI logs       |

## Point allocation

| Task | Pts | Title                                                |
| ---- | --- | ---------------------------------------------------- |
| 01   | 15  | Inventory + ansible.cfg                              |
| 02   | 15  | yum-repo.yml (BaseOS + AppStream)                    |
| 03   | 15  | packages.yml (php/mariadb/group/updates)             |
| 04   | 15  | timesync system role                                 |
| 05   | 25  | apache role + apache-role.yml                        |
| 06   | 10  | requirements.yml (zabbix, security, squid)           |
| 07   | 10  | squid.yml on balancers                               |
| 08   | 20  | test.yml — setgid dir + symlink + index.html         |
| 09   | 10  | ansible-vault create                                 |
| 10   | 20  | hosts.j2 → /etc/myhosts                              |
| 11   | 15  | hwreport.yml                                         |
| 12   | 15  | /etc/issue per host group                            |
| 13   | 10  | vault rekey                                          |
| 14   | 25  | create_user.yml (vault + SHA512)                     |
| 15   | 15  | cron.yml — natasha                                   |
| 16   | 20  | lvm.yml — research/data                              |
| 17   | 25  | partition.yml — /dev/sdb /srv mount on prod          |
| 18   | 20  | selinux role + ansible-navigator                     |
| —    | 300 | total (70 % passing line = 210)                      |

## Idempotency-check tolerances

One task uses a module that is inherently non-idempotent and is
whitelisted (apply twice but only fail on `failed=`, not `changed=`):

- **Task 3** — `ansible.builtin.dnf state: latest` on the "update all
  packages" task is non-idempotent when upstream has new errata
  (Ansible issue #64963). This is intended behavior for that specific
  ask; `state: latest` on the *named* packages was switched back to
  `state: present` in the updated reference solution.

Every other task is required to be cleanly idempotent — including
task 14, whose reference solution now uses an explicit salt
(`password_hash('sha512', 'rh294salt')`) plus `update_password: on_create`.

## Adding a new task script

Drop `scripts/verify/tasks/task-NN.sh` matching this skeleton:

```bash
#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables consumed after `source` from verify-all.sh
TASK_NUM=NN
TASK_TITLE="…"
TASK_POINTS=15

task_apply() {            # optional — only called under --apply
    playbook_idempotent foo.yml
}
task_verify() {           # required — must populate SCORE_POINTS / SCORE_MAX
    score_check 2 "file exists" test -f "$ANSIBLE_DIR/foo.yml"
    score_check 3 "node1: thing X" node_sudo node1 "test -f /etc/x"
}
task_reboot_survival() {  # optional — defaults to task_verify
    task_verify
}
```

Helpers (from `lib/common.sh`):

- `score_check <pts> <label> <command…>` — pass if the command returns 0
- `score_assert <pts> <label> <expected> <command…>` — pass if command
  output contains the expected substring
- `node_ssh <node> <cmd>` / `node_sudo <node> <cmd>` — remote exec
- `playbook_idempotent <playbook> [args…]` — apply twice, fail if
  second run reports `changed=` or `failed=` per host
- `reboot_nodes_and_wait <node…>` — graceful reboot + SSH retry
- `ALL_NODES`, `DEV_NODES`, `TEST_NODES`, `PROD_NODES`,
  `BALANCER_NODES`, `WEB_NODES` — group arrays

## Exit codes

| Code | Meaning                                              |
| ---- | ---------------------------------------------------- |
| 0    | Score >= passing threshold                           |
| 1    | Score < passing threshold                            |
| 2    | Bash too old (need 4+)                               |

## How this maps to the real EX294 grader

The real grader is opaque, but per Red Hat's own EX294 page it
"evaluat[es] by applying the playbooks created during the exam against
freshly installed systems and verifying that those systems and services
work as specified." This script does the same thing locally:

- **Apply** the student's playbooks against the 5 managed nodes.
- **Verify** the end state with SSH-based state probes.
- **Reboot survival** as a separate pass — the grader is widely
  reported to reboot before final state-collection.

Caveats:

- The real grader's per-task point allocation is not public. Numbers here
  are heuristic (totals to 300, weighted by task complexity).
- The reference solutions in `lab/solutions/` have known idempotency
  gaps (task 14) and provider-portability gaps (task 17). See
  [`docs/explanation/known-task-discrepancies.md`](../../docs/explanation/known-task-discrepancies.md).
