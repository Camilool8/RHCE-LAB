# RHCE-LAB Design

**Date:** 2026-05-19
**Status:** Approved
**Approach:** A — Host CLI + control-node grader

## Purpose

An automated, reproducible practice lab for the **RHCE 9 (EX294)** exam, built in
the same fashion as the existing `RHCSA-LAB` (Vagrant + VirtualBox, `config.yaml`-driven,
shell-script provisioning, snapshot-based reset). It deploys a full Ansible
control-node + managed-node topology, lets the user snapshot and reset cleanly,
practice individual tasks, and run a timed full-exam simulation with automated
grading.

Task and solution content is sourced from the `rhce9-ex294-practice-lab-main`
repository (18 tasks). That repository distributes pre-built cloneable disk
images; this lab replaces that delivery model with Vagrant provisioning so the
whole environment comes up with a single `vagrant up`.

## Goals

- One-command deploy (`vagrant up`) of the complete 7-VM topology.
- Snapshot / reset workflow for re-attempting tasks from a clean baseline.
- Practice individual tasks or run a timed 4-hour full-exam simulation.
- Automated grading of all 18 tasks with an EX294-style score.
- Fully reproducible offline (after first provision) when an ISO is supplied.

## Non-Goals

- Reproducing the exact upstream pre-built `.raw`/`.qcow2`/`.vmdk` images.
- KVM/libvirt or VMware support — VirtualBox only, matching `RHCSA-LAB`.
- Authoring new exam tasks — the 18 upstream tasks are used as-is.

## Topology

Seven VirtualBox VMs on a VirtualBox private network. Subnet, RAM, and CPU
are tunable in `config.yaml`.

| VM | Hostname | Private IP | RAM | vCPU | Role |
|----|----------|-----------|-----|------|------|
| repo-server | `repo-server` | 192.168.56.40 | 1 GB | 2 | HTTP repos (BaseOS/AppStream), NFS exports, GPG key host |
| control | `ansible-control` | 192.168.56.50 | 2 GB | 2 | Ansible control node + grading harness |
| node1 | `node1` | 192.168.56.51 | 1.25 GB | 1 | Managed node — group `dev` |
| node2 | `node2` | 192.168.56.52 | 1.25 GB | 1 | Managed node — group `test` |
| node3 | `node3` | 192.168.56.53 | 1.25 GB | 1 | Managed node — group `prod` |
| node4 | `node4` | 192.168.56.54 | 1.25 GB | 1 | Managed node — group `prod` |
| node5 | `node5` | 192.168.56.55 | 1.25 GB | 1 | Managed node — group `balancers` |

Estimated host footprint: **~9.5 GB RAM, ~9 vCPU oversubscribed, ~80 GB disk**.
Dropping to 3 managed nodes (lighter) is a `config.yaml` edit; the grader and
solutions assume the full 5-node topology by default.

Each VM has two NICs: NAT (Vagrant default, internet access) and the private
network. Internet on the managed nodes is needed for task 6 (Ansible Galaxy
role downloads); on the control node for the ansible-navigator execution
environment image pull.

### Baked-in inventory

The lab provisions hosts so the upstream solutions resolve unchanged:

```
[dev]      node1
[test]     node2
[prod]     node3, node4
[balancers] node5
[webservers:children] prod
```

Short names `node1`..`node5` are used, with `ansible-node-1`..`ansible-node-5`
as `/etc/hosts` aliases for compatibility with upstream answer keys.

### Users and access

- `x69van` / password `1234` on all VMs (sudo). All task paths hardcode
  `/home/x69van/ansible/...`, so this account name is mandatory.
- `redhat` / password `redhat` on all VMs (sudo) — convenience admin account,
  matching `RHCSA-LAB` conventions.
- SSH keypair `RH294-LAB` generated on the control node during provisioning and
  its public key installed in `x69van`'s `authorized_keys` on every managed
  node. `ansible.cfg` references `~/.ssh/RH294-LAB`.

## OS and Repositories

- Default Vagrant box: `almalinux/9`. The EX294 tasks reference AlmaLinux GPG
  keys, so AlmaLinux is the natural fit.
- ISO auto-detect (RHCSA-LAB pattern): if a RHEL/AlmaLinux 9 ISO is placed in
  `iso/`, the Vagrantfile attaches it to the repo-server, which serves its
  BaseOS/AppStream content. If no ISO is present, the repo-server `reposync`s
  BaseOS and AppStream from public AlmaLinux mirrors during provisioning
  (requires internet on first `vagrant up` only).
- The repo-server serves repos two ways:
  - **HTTP** at `http://192.168.56.40/repo/{BaseOS,AppStream}/` — used by all
    VMs as their system `dnf` repos during provisioning and practice.
  - **NFS export** of the same BaseOS/AppStream trees — each managed node
    mounts them at `/mnt/BaseOS` and `/mnt/AppStream`, so task 2's
    `baseurl=file:///mnt/BaseOS/` repos genuinely resolve.
- The AlmaLinux GPG key is staged at
  `/etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9` on every managed node, as task 2
  expects.

## Managed-node storage

Each managed node receives two extra VirtualBox disks:

- `/dev/sdb` — 2 GB, left raw/unpartitioned. Used by task 17 (create a 1200 MB
  primary partition; the size-fallback and missing-disk branches are exercised
  by playbook logic).
- `/dev/sdc` — 2 GB, pre-built into a physical volume and the `research` volume
  group, left with free space. Used by task 16 (create logical volume `data` in
  VG `research`; size-fallback branch exercised by playbook logic).

Two separate disks keep task 16 and task 17 from colliding over the same device.

## Provisioning

Shell-script provisioning, organized like `RHCSA-LAB/scripts/`:

```
scripts/
  common/
    base-setup.sh          # packages, firewalld, SELinux, HTTP repo client config
    create-users.sh        # x69van + redhat accounts
  repo-server/
    setup-repos.sh         # ISO-or-reposync -> /var/www/html/repo, httpd
    setup-nfs.sh           # NFS-export BaseOS/AppStream
    setup-gpg.sh           # publish AlmaLinux GPG key
  control/
    setup-control.sh       # ansible-core, ansible-navigator, rhel-system-roles,
                           # RH294-LAB key gen + distribution, /etc/hosts,
                           # EE image pre-pull, sample ansible.cfg + .vimrc
    install-grader.sh      # deploy grading harness to /home/x69van/grader
  node/
    setup-node.sh          # authorize RH294-LAB key, build sdb/sdc + research VG,
                           # mount /mnt/{BaseOS,AppStream}, stage GPG key
```

`files/` holds static assets: sample `ansible.cfg`, `.vimrc` (the upstream
ansible-doc Vim mapping), the GPG key, NFS `exports`, and the
ansible-navigator settings used for the EE pre-pull.

Provisioning order per VM mirrors `RHCSA-LAB`: `base-setup.sh` ->
`create-users.sh` -> role-specific scripts. The Vagrantfile brings up
`repo-server` first, then `control`, then `node1`..`node5`.

### Execution environment (task 18)

Task 18 uses `ansible-navigator`. `setup-control.sh` pre-pulls a community
execution-environment image (`quay.io/ansible/creator-ee` or equivalent) via
`podman` so `ansible-navigator run` works during practice. If the pull fails
(no internet), provisioning continues and ansible-navigator remains usable with
`--execution-environment false`; this is noted in the README.

## Host CLI — `bin/rhce-lab`

A POSIX shell wrapper on the host, the primary enhancement over `RHCSA-LAB`.
It shells out to `vagrant` and `VBoxManage` and SSHes into the control node.

| Command | Behavior |
|---------|----------|
| `rhce-lab up` | `vagrant up`; on success take the `clean` snapshot of every VM |
| `rhce-lab status` | `vagrant status` plus snapshot list per VM |
| `rhce-lab check` | Preflight: `ansible all -m ping` from control, repo HTTP reachability, NFS mounts, extra disks present |
| `rhce-lab snapshot <name>` | Take a named VBoxManage snapshot of all VMs |
| `rhce-lab reset [node\|all]` | Restore the `clean` snapshot for one VM or all, then `vagrant up` |
| `rhce-lab grade [NN\|all]` | Run grader(s) on the control node; print per-task pass/fail |
| `rhce-lab exam start` | Snapshot `exam-baseline`, start a 4-hour timer, hide `lab/solutions/` |
| `rhce-lab exam status` | Show elapsed/remaining exam time |
| `rhce-lab exam grade` | Run all 18 graders, print EX294-style score, restore `solutions/` visibility |
| `rhce-lab solutions [NN]` | Print a solution (blocked while an exam is in progress) |

VM names in VirtualBox are prefixed `rhce-` (e.g. `rhce-ansible-control`),
matching the `rhcsa-` convention.

## Grading harness

Deployed to `/home/x69van/grader/` on the control node by `install-grader.sh`:

```
grader/
  grade.sh               # dispatcher: runs grade-NN.sh, aggregates, scores
  grade-01.sh ... grade-18.sh
  lib/common.sh          # shared helpers: assert, on_node, score reporting
```

**Grading model — end-state verification.** The student runs their own
playbooks first; graders then verify the resulting end-state. Graders do **not**
run the student's playbooks for them. Each `grade-NN.sh`:

1. Checks the required artifact exists on the control node (e.g.
   `/home/x69van/ansible/issue.yml`, `inventory`, `ansible.cfg`).
2. Verifies the end-state on the relevant managed nodes via `ansible` ad-hoc
   commands or SSH (e.g. task 12: `/etc/issue` content per host group; task 5:
   HTTP `curl` of each webserver; task 16: `lvs` shows `data` in `research`).
3. Emits `PASS`/`FAIL` per sub-requirement and a task subtotal.

Scoring: each task is weighted to total 300 points; `grade.sh` prints the sum
and the EX294 pass line (>= 210/300). Weighting lives in a single table in
`grade.sh` for easy tuning.

Examples of per-task checks:

- Task 1 — inventory groups and `ansible.cfg` keys are correct.
- Task 4 — `chronyd` on managed nodes points at `172.25.254.250` with `iburst`.
- Task 6 — `zabbix`, `security`, `squid` role directories exist under `roles/`.
- Task 9/13 — `vault.yml` is encrypted and decrypts with the expected password.
- Task 17 — `/dev/sdb1` is ~1200 MB, ext4; mounted at `/srv` on prod nodes.
- Task 18 — SELinux mode matches the playbook run on all nodes.

## `lab/` folder

```
lab/
  tasks/         task-01.txt ... task-18.txt   (from upstream, hostnames/IPs adapted)
  solutions/     answer-01.md ... answer-18.md (from upstream, adapted)
  exam-blueprint.md   maps each task to EX294 objectives + point weight
```

## Workflows

**Initial deploy**
```
cd RHCE-LAB
cp /path/to/alma-9-dvd.iso iso/      # optional
bin/rhce-lab up                      # vagrant up + clean snapshot
bin/rhce-lab check                   # verify ping/repos/disks
```

**Practice one task**
```
# read lab/tasks/task-12.txt, write the playbook on the control node, run it
bin/rhce-lab grade 12
bin/rhce-lab reset all               # back to clean baseline
```

**Timed full exam**
```
bin/rhce-lab exam start              # exam-baseline snapshot, 4h timer, solutions hidden
# ... work the 18 tasks ...
bin/rhce-lab exam grade              # score vs 210/300 pass line
bin/rhce-lab reset all
```

## Error handling

- **No ISO present:** repo-server falls back to `reposync` from public mirrors;
  README documents the internet requirement on first provision.
- **EE image pull fails:** provisioning continues; ansible-navigator usable with
  `--execution-environment false`.
- **`reset` while VMs are off:** restore snapshot, then `vagrant up`.
- **Grader run before student artifact exists:** grader reports `FAIL` with a
  clear "artifact not found" message rather than erroring out.
- **`solutions` access during an exam:** `rhce-lab solutions` refuses while an
  exam is in progress; `exam grade` re-enables it.

## Repository layout

```
RHCE-LAB/
  Vagrantfile
  config.yaml
  README.md
  .gitignore
  bin/rhce-lab
  iso/README.md
  scripts/         (see Provisioning)
  files/           (ansible.cfg, .vimrc, GPG key, exports, navigator config)
  lab/             (tasks/, solutions/, exam-blueprint.md)
  grader/          (source of the grading harness, deployed to the control node)
  docs/superpowers/specs/2026-05-19-rhce-lab-design.md
```

## Open follow-ups (not blocking)

- Confirm a working community EE image tag at build time.
- Decide final point weights per task in `exam-blueprint.md` (default: equal-ish,
  summing to 300).
