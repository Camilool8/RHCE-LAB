# First run: from zero to `ansible all -m ping`

This tutorial walks you from an empty machine to a working seven-VM Ansible lab
where the control node can manage all five managed nodes. Expect 30 to 60
minutes the first time, mostly spent waiting for the box image to download
and for VMs to provision.

## What you will end with

```
[student@ansible-control ~]$ ansible all -m ping
node1 | SUCCESS => { "ping": "pong", ... }
node2 | SUCCESS => { "ping": "pong", ... }
node3 | SUCCESS => { "ping": "pong", ... }
node4 | SUCCESS => { "ping": "pong", ... }
node5 | SUCCESS => { "ping": "pong", ... }
```

## What you need before you start

- A computer with **at least 10 GB of free RAM and 80 GB of free disk**.
- The ability to run `sudo` on your machine.
- An internet connection (the first run downloads a ~2 GB box image plus
  packages).

## Step 1 — Install the prerequisites for your host

Follow [Install prerequisites](../how-to/install-prerequisites.md). Stop and
come back here when you can run `vagrant --version` and your hypervisor command
(`VBoxManage --version`, `prlctl --version`, or `vmrun -T fusion`).

## Step 2 — Get the lab files

```bash
git clone <repo-url> RHCE-LAB
cd RHCE-LAB
```

## Step 3 — Bring up the lab

```bash
vagrant up
```

The first line of output prints the chosen provider:

```
==> RHCE-LAB: host=macos/arm64 provider=parallels box_arch=arm64
```

The provider is auto-detected from your host OS and CPU architecture. If the
auto-detected provider is not the one you have installed, override it:

```bash
LAB_PROVIDER=vmware_desktop vagrant up    # force VMware Fusion on a Mac
```

See [Override variables](../reference/overrides.md) for the full list.

Provisioning takes 15 to 30 minutes. You can safely walk away — do **not**
open extra terminals to run `vagrant ssh` against the lab while `vagrant up`
is in progress; concurrent SSH sessions can interrupt the provisioner.

## Step 4 — Confirm the lab is up

```bash
vagrant status
```

All seven VMs should be `running`:

```
repo                      running
control                   running
node1                     running
node2                     running
node3                     running
node4                     running
node5                     running
```

## Step 5 — Test connectivity from the control node

```bash
vagrant ssh control
```

You are now `vagrant` on the control node. Switch to the practice user:

```bash
sudo -iu student
```

Write a minimal inventory and `ansible.cfg`:

```bash
mkdir -p ~/ansible && cd ~/ansible
cat > inventory <<'EOF'
[all]
node1
node2
node3
node4
node5
EOF

cat > ansible.cfg <<'EOF'
[defaults]
inventory=./inventory
remote_user=student
host_key_checking=False
private_key_file=~/.ssh/RH294-LAB
EOF
```

Run the ping:

```bash
/usr/bin/ansible all -m ping
```

You should see five `SUCCESS` lines, one per node. Use the explicit
`/usr/bin/ansible` path — see [Work around the pip-ansible "Illegal instruction"
crash](../how-to/work-around-ansible-illegal-instruction.md) for why.

## Step 6 — Take a clean baseline snapshot

Once you have a working lab, take a snapshot you can revert to between
practice sessions. See [Snapshot and revert](../how-to/snapshot-and-revert.md).

## Where to go next

- Read your first exam task: open [`lab/tasks/task-01.txt`](../../lab/tasks/task-01.txt).
- Learn the daily workflow: [Practice one of the 18 exam tasks](../how-to/practice-a-task.md).
- Try `ansible-navigator`: [Use `ansible-navigator`](../how-to/use-ansible-navigator.md).
