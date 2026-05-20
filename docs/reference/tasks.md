# Exam tasks

The 18 EX294 practice tasks live in `lab/tasks/` and their reference
solutions in `lab/solutions/`. Read a task with:

```bash
cat lab/tasks/task-01.txt
```

## Task summary

| #   | Topic                                                   | Required filename(s) on the control node                                       |
| --- | ------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 1   | Install Ansible, build inventory + `ansible.cfg`        | `/home/student/ansible/inventory`, `/home/student/ansible/ansible.cfg`         |
| 2   | Create yum repositories on managed nodes via playbook   | `/home/student/ansible/yum-repo.yml`                                           |
| 3   | Install packages and groups by host group               | `/home/student/ansible/packages.yml`                                           |
| 4   | RHEL system roles — configure `timesync`                | `/home/student/ansible/timesync.yml`                                           |
| 5   | Create a `apache` role + playbook to use it             | `/home/student/ansible/roles/apache/`, `/home/student/ansible/apache-role.yml` |
| 6   | Download roles from Galaxy via `requirements.yml`       | `/home/student/ansible/roles/requirements.yml`                                 |
| 7   | Use the downloaded `squid` role                         | `/home/student/ansible/squid.yml`                                              |
| 8   | Create directory + symlink with SELinux + special perms | `/home/student/ansible/test.yml`                                               |
| 9   | Create an Ansible Vault                                 | `/home/student/ansible/vault.yml`, `/home/student/ansible/password.txt`        |
| 10  | Generate `/etc/myhosts` from a Jinja2 template          | `/home/student/ansible/hosts.j2`, `/home/student/ansible/gen_hosts.yml`        |
| 11  | Hardware report playbook                                | `/home/student/ansible/hwreport.yml`                                           |
| 12  | Per-group `/etc/issue` content                          | `/home/student/ansible/issue.yml`                                              |
| 13  | Rekey the vault from task 9                             | (reuses `vault.yml`)                                                           |
| 14  | Create users by job description, using the vault        | `/home/student/ansible/user_list.yml`, `/home/student/ansible/create_user.yml` |
| 15  | Cron jobs via Ansible                                   | `/home/student/ansible/cron.yml`                                               |
| 16  | Logical volume in the existing `research` VG            | `/home/student/ansible/lvm.yml`                                                |
| 17  | Partition + mount on extra disk                         | `/home/student/ansible/partition.yml`                                          |
| 18  | SELinux role + `ansible-navigator`                      | `/home/student/ansible/selinux.yml`, `selinux2.yml`                            |

## Conventions

- Task descriptions use `node1` through `node5` for managed nodes. These
  hostnames match the lab's inventory exactly — no aliasing is needed.
- Tasks expect to run as `student` on the control node, from
  `/home/student/ansible/`.
- The `research` volume group used by task 16 is pre-created on each
  managed node. See [Storage layout](storage-layout.md).
- Task 17's raw disk has a different device name on every provider
  (`/dev/sdb`, `/dev/vdb`, or `/dev/nvme0n2`). The task description
  explicitly asks the student to discover it at runtime via
  `ansible_facts.devices` — the reference solution shows the canonical
  pattern.

## Scoring your work

The lab includes an EX294-style grader at
[`scripts/verify/`](../../scripts/verify/README.md). It is preinstalled
on the control node at `/home/student/verify/`. Run as `student`:

```bash
~/verify/verify-all.sh           # state-only audit, fast
~/verify/verify-all.sh --apply   # re-run all playbooks (twice each, idempotency-checked)
~/verify/verify-all.sh --reboot  # add a reboot-survival pass
```

It prints a per-task scorecard and a 300-point total against the standard
210/300 passing line.

## Related

- [How-to: practice a task](../how-to/practice-a-task.md).
- [Storage layout](storage-layout.md) — which device is which.
- [Known task discrepancies](../explanation/known-task-discrepancies.md) —
  where tasks, solutions, and lab state don't quite agree.
