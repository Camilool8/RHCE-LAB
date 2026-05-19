# RHCE-LAB

Automated RHCE 9 (EX294) practice lab — a 7-VM Ansible environment deployed
with Vagrant + VirtualBox. Companion to RHCSA-LAB.

> Grading automation and the `bin/rhce-lab` exam CLI are delivered by a
> follow-up plan (Grading & Exam Tooling). This README covers the
> infrastructure and manual practice workflow.

## Prerequisites

- VirtualBox 7.0+
- Vagrant 2.4+
- Host resources: ~10 GB free RAM, ~80 GB disk, virtualization enabled
- Internet access on first `vagrant up` (box download, packages, task 6
  Galaxy roles, task 18 execution-environment image)

## Topology

| VM       | Hostname          | IP             | RAM     | Role                         |
|----------|-------------------|----------------|---------|------------------------------|
| repo     | repo-server       | 192.168.56.40  | 1 GB    | HTTP repos + NFS + GPG key   |
| control  | ansible-control   | 192.168.56.50  | 2 GB    | Ansible control node         |
| node1    | node1             | 192.168.56.51  | 1.25 GB | managed node — group `dev`   |
| node2    | node2             | 192.168.56.52  | 1.25 GB | managed node — group `test`  |
| node3    | node3             | 192.168.56.53  | 1.25 GB | managed node — group `prod`  |
| node4    | node4             | 192.168.56.54  | 1.25 GB | managed node — group `prod`  |
| node5    | node5             | 192.168.56.55  | 1.25 GB | managed node — group `balancers` |

All values are tunable in `config.yaml`.

## Quick Start

```bash
cd RHCE-LAB
cp /path/to/AlmaLinux-9-DVD.iso iso/      # optional — see iso/README.md
vagrant up                                 # 15-25 min on first run
```

## Accounts

- `x69van` / `1234` — the RHCE practice user (all task paths use `/home/x69van`)
- `redhat` / `redhat` — convenience admin account
- Both have passwordless `sudo`.

The control node holds the `RH294-LAB` SSH key at
`/home/x69van/.ssh/RH294-LAB`; its public key is authorized for `x69van` on
every managed node.

## Practice Workflow

```bash
vagrant ssh control
sudo -iu x69van          # become the practice user

# Task 1 asks you to build the inventory and ansible.cfg.
# A reference ansible.cfg is in the repo at files/ansible.cfg.
```

Verify connectivity once your inventory exists:

```bash
ansible all -m ping
```

Work the tasks in `lab/tasks/`; check yourself against `lab/solutions/`.

### Snapshots and reset

```bash
# Take a clean baseline after first provisioning
VBoxManage snapshot rhce-ansible-control take clean
VBoxManage snapshot rhce-node1 take clean
# ... repeat for node2..node5 and rhce-repo-server

# Restore
VBoxManage snapshot rhce-node1 restore clean
vagrant up node1
```

## Repositories

- `http://192.168.56.40/repo/BaseOS/` and `/AppStream/` — HTTP repos.
- Each managed node NFS-mounts those trees at `/mnt/BaseOS` and
  `/mnt/AppStream` (used by task 2's `file://` repositories).
- With an ISO in `iso/`, the repos hold the full package set. Without one,
  they are empty-but-valid structures and nodes use AlmaLinux internet repos.

## Storage layout (managed nodes)

- `/dev/sdb` — 2 GB, raw/unpartitioned — used by task 17.
- `/dev/sdc` — 2 GB, pre-built into volume group `research` — used by task 16.

## Common Commands

```bash
vagrant status
vagrant up [name]
vagrant halt
vagrant ssh control
vagrant destroy -f
VBoxManage snapshot <vm> list
```

## Troubleshooting

- **ISO not detected:** confirm a single `*.iso` in `iso/`, then
  `vagrant reload --provision repo`.
- **`ansible all -m ping` fails:** confirm your inventory uses `node1`..`node5`
  and `ansible.cfg` sets `private_key_file = ~/.ssh/RH294-LAB`.
- **NFS `/mnt` not mounted on a node:** `sudo mount -a` (the repo server may
  have provisioned after the node).
- **ISO attach fails on `vagrant up`:** the box may name its storage
  controller differently; adjust `--storagectl` in the Vagrantfile.

## License

MIT — free to use and modify for RHCE preparation.
