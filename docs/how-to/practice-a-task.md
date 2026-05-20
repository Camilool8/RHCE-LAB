# Practice one of the 18 exam tasks

The lab ships with the 18 EX294 practice tasks in `lab/tasks/` and reference
solutions in `lab/solutions/`. This is the workflow for working through one.

## Step 1 — Read the task

From the repository root:

```bash
cat lab/tasks/task-01.txt
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

```bash
ansible-playbook ~/ansible/task-01.yml
```

Or, if you prefer the exam-realistic `ansible-navigator`:

```bash
ansible-navigator run ~/ansible/task-01.yml --mode stdout
```

See [Use ansible-navigator](use-ansible-navigator.md).

## Step 5 — Verify

The task description tells you what to verify. Common patterns:

```bash
# Run an ad-hoc check
ansible all -m shell -a 'cat /etc/myhosts'

# SSH to a managed node and inspect directly
ssh -i ~/.ssh/RH294-LAB student@node1
```

## Step 6 — Compare with the reference solution

```bash
exit             # leave the student shell
exit             # leave the control VM
cat lab/solutions/answer-01.md
```

The reference solutions are intentionally terse — they show _a_ valid answer,
not the only one.

## Step 7 — Reset for the next attempt

To attempt the same task again from a known-good state, see [Snapshot and
revert](snapshot-and-revert.md).

## Tip — Keep the inventory file across resets

If you used the inventory + `ansible.cfg` from the [tutorial](../tutorial/first-run.md),
they are stored in `/home/student/ansible/` inside the control VM. Reverting
to the `clean` snapshot also reverts those files. Keep a copy outside the VM
(on the host or in a git repo) if you do not want to recreate them every time.
