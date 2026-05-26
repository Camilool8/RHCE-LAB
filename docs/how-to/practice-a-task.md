# Practice one of the 18 exam tasks

The lab ships with the 18 EX294 practice tasks in `lab/tasks/` and reference
solutions in `lab/solutions/`. This is the workflow for working through one.

## Step 1 — Read the task

From the repository root:

```bash
cat lab/tasks/task-01.md
```

Or open the file in your editor.

## Step 2 — Open a shell on the control node

```bash
vagrant ssh control
sudo -iu student
cd ~/ansible
```

You are now `student` in `/home/student/ansible` — the directory the exam
tasks expect to find playbooks and the inventory in.

## Step 3 — Write the playbook

Use your editor of choice. `vim` is pre-installed with helpful settings (see
[Accounts and keys](../reference/accounts-and-keys.md) for the `~/.vimrc` that
is dropped in).

```bash
vim ~/ansible/task-01.yml
```

Note: tasks 1 and onward expect specific filenames. The exact filename is in
the task description.

## Step 4 — Run the playbook

The exam runner is `ansible-navigator`. Use it by default:

```bash
ansible-navigator run ~/ansible/task-01.yml --mode stdout
```

Or, equivalently, run the same playbook with `ansible-playbook` —
fewer moving parts, faster start, identical result when the EE image
isn't doing anything you couldn't do on the host:

```bash
ansible-playbook ~/ansible/task-01.yml
```

Both runners exit non-zero on the same failures, so either works for
the verifier. See [Use ansible-navigator](use-ansible-navigator.md)
for the full subcommand reference (including
`ansible-navigator doc` for looking up plugin docs and examples
offline).

## Step 5 — Verify

Two ways:

**Quick** — ad-hoc Ansible commands against the relevant group:

```bash
ansible all -m shell -a 'cat /etc/myhosts'
ssh -i ~/.ssh/RH294-LAB student@node1
```

**Thorough** — the task verifier scores your work the way the EX294
grader would (apply twice for idempotency, SSH-check end state, reboot
survival). It is preinstalled at `/home/student/verify/`:

```bash
vagrant ssh control
sudo -iu student
~/verify/verify-all.sh --task 1
```

See [`scripts/verify/README.md`](../../scripts/verify/README.md) for
the full flag list. The verifier sums to 300 points across all 18
tasks; passing line is 210 (70 %). If you edit verifier scripts on
the host, push them with `vagrant provision control`.

## Step 6 — Compare with the reference solution

```bash
exit             # leave the student shell
exit             # leave the control VM
cat lab/solutions/answer-01.md
```

Each reference solution shows _a_ valid answer (not the only one) plus
a "What this teaches" section and best-practice notes — read those even
if your own answer passed the verifier. Caveats and intentional
fixes-to-the-original-spec are catalogued in
[Known task discrepancies](../explanation/known-task-discrepancies.md).

## Step 7 — Reset for the next attempt

To attempt the same task again from a known-good state, see [Snapshot and
revert](snapshot-and-revert.md).

## Tip — Keep the inventory file across resets

If you used the inventory + `ansible.cfg` from the [tutorial](../tutorial/first-run.md),
they are stored in `/home/student/ansible/` inside the control VM. Reverting
to the `clean` snapshot also reverts those files. Keep a copy outside the VM
(on the host or in a git repo) if you do not want to recreate them every time.
