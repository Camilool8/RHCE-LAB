# RHCE-LAB

Automated RHCE 9 (EX294) practice lab — a 7-VM Ansible environment deployed
with Vagrant. Companion to RHCSA-LAB. Runs natively on macOS (Intel and Apple
Silicon), Linux (x86_64 and arm64), and Windows.

> Grading automation and the `bin/rhce-lab` exam CLI are delivered by a
> follow-up plan (Grading & Exam Tooling). This README covers the
> infrastructure and manual practice workflow.

## Supported scenarios

The lab runs **native-arch only** — guests match the host CPU. No cross-arch
emulation.

| Scenario | Host | Auto-selected provider | Plugin to install |
|---|---|---|---|
| **Native x86_64** | macOS Intel | `virtualbox` | (built-in) |
| | Linux x86_64 | `libvirt` | `vagrant-libvirt` |
| | Windows x86_64 | `virtualbox` | (built-in) |
| **Native arm64** | macOS Apple Silicon | `parallels` | `vagrant-parallels` |
| | Linux arm64 | `libvirt` (kvm) | `vagrant-libvirt` |

`vmware_desktop` is supported as a fallback on every host that has VMware
Fusion or Workstation installed (free for personal use post-Broadcom). It is
the recommended choice for Apple Silicon Macs without Parallels Desktop.

Selection order:
1. `vagrant up --provider <name>` (CLI flag)
2. `LAB_PROVIDER=<name>` env var
3. `providers.default` in `config.yaml`
4. Auto-detect from `(host_os, host_arch)`

## Prerequisites by host

### macOS Intel
- Install [VirtualBox 7.x](https://www.virtualbox.org/wiki/Downloads) and
  [Vagrant 2.4+](https://www.vagrantup.com/downloads).

### macOS Apple Silicon
Pick one — both are native-arm64 with hardware acceleration:

- **Parallels Desktop** (paid, Pro or Business edition required by
  `vagrant-parallels`)
  - Install from [parallels.com](https://www.parallels.com/products/desktop/)
  - `vagrant plugin install vagrant-parallels`
- **VMware Fusion** (free for personal use)
  - Free Broadcom account → download Fusion 13.x
  - `vagrant plugin install vagrant-vmware-desktop`
  - Run with: `LAB_PROVIDER=vmware_desktop vagrant up`

If you have neither, run the lab on a Linux x86_64 host (cloud VM, Intel Mac,
etc.) — no code change needed.

### Linux x86_64 or arm64
- Install Vagrant 2.4+, qemu, and libvirt:
  - Fedora/AlmaLinux/Rocky: `sudo dnf install @virtualization libguestfs-tools libvirt-devel`
  - Debian/Ubuntu: `sudo apt install qemu-system libvirt-daemon-system libvirt-dev ebtables libguestfs-tools`
- `sudo systemctl enable --now libvirtd`
- `vagrant plugin install vagrant-libvirt`

### Windows x86_64
- Install VirtualBox 7.x and Vagrant 2.4+. Disable Hyper-V (or accept
  the VirtualBox-on-Hyper-V coexistence performance penalty).

## Quick start

```bash
cd RHCE-LAB
cp /path/to/AlmaLinux-9-DVD.iso iso/      # optional — see iso/README.md
vagrant up                                 # ~15-25 min on first run
```

The Vagrantfile prints the chosen provider on the first line:

```
==> RHCE-LAB: host=macos/arm64 provider=parallels box_arch=arm64
```

## Topology

| Vagrant name | Hostname          | IP            | RAM     | Role                       |
|--------------|-------------------|---------------|---------|----------------------------|
| repo         | repo-server       | 192.168.56.40 | 1 GB    | HTTP repos + NFS + GPG key |
| control      | ansible-control   | 192.168.56.50 | 2 GB    | Ansible control node       |
| node1        | node1             | 192.168.56.51 | 1.25 GB | managed node — `dev`       |
| node2        | node2             | 192.168.56.52 | 1.25 GB | managed node — `test`      |
| node3        | node3             | 192.168.56.53 | 1.25 GB | managed node — `prod`      |
| node4        | node4             | 192.168.56.54 | 1.25 GB | managed node — `prod`      |
| node5        | node5             | 192.168.56.55 | 1.25 GB | managed node — `balancers` |

Edit `config.yaml` to tune subnet, RAM/CPU, node count, etc.

## Accounts

- `student` / `1234` — the RHCE practice user (every task path uses `/home/student`).
- `redhat` / `redhat` — convenience admin.
- Both have passwordless `sudo`.

The control node holds the `RH294-LAB` SSH key at
`/home/student/.ssh/RH294-LAB`; its public key is authorized for `student` on
every managed node.

## Storage layout (managed nodes)

Each managed node carries two extra virtual disks. Their device names depend
on the provider's preferred bus:

| Provider | Bus | First extra | Second extra |
|---|---|---|---|
| virtualbox | SCSI/SATA | `/dev/sdb` | `/dev/sdc` |
| parallels | SCSI/SATA | `/dev/sdb` | `/dev/sdc` |
| libvirt | virtio | `/dev/vdb` | `/dev/vdc` |
| vmware_desktop | NVMe | `/dev/nvme0n2` | `/dev/nvme0n3` |

The first extra disk is left raw for task 17. The second extra disk is
pre-built into the volume group `research` for task 16. Provisioning scripts
detect all three device-name families — students writing playbooks should
accept all three (or use `lsblk` to detect at runtime).

## Networking and firewall

- The lab subnet (`192.168.56.0/24` by default) is delivered via Vagrant's
  `private_network` but configured in-guest by
  `scripts/common/configure-lab-network.sh` using NetworkManager keyfiles —
  Vagrant's RedHat guest capability writes obsolete `/etc/sysconfig/network-
  scripts/ifcfg-*` files that AlmaLinux 9.6+ no longer reads
  ([HashiCorp Vagrant #13744](https://github.com/hashicorp/vagrant/issues/13744)).
- The connection lands in firewalld's **`internal`** zone, with the lab
  subnet also bound by source — so policy is correct even if NetworkManager
  zone integration drifts.
- The repo server opens `http`, `nfs`, `mountd`, and `rpc-bind` on the
  `internal` zone only. The public/NAT interface stays defended.

## ansible-navigator

`scripts/control/setup-control.sh` installs ansible-navigator robustly:

1. **On RHEL with an active Ansible Automation Platform subscription** —
   enables `ansible-automation-platform-2.5-for-rhel-9-$(uname -m)-rpms` via
   `subscription-manager` and runs `dnf install ansible-navigator`. This is
   the same path an exam environment uses.
2. **Otherwise** (AlmaLinux, Rocky, unsubscribed RHEL) — falls back to
   `python3.11 -m pip install --user ansible-dev-tools` as the `student`
   user. `python3.11` is needed because `ansible-dev-tools` requires Python
   ≥ 3.10 (AlmaLinux 9 ships 3.9 as the platform Python).

A `~/.ansible-navigator.yml` is dropped on the control node pointing at
`ghcr.io/ansible/community-ansible-dev-tools:latest` — the maintained
multi-arch (amd64+arm64) execution-environment image (the older
`quay.io/ansible/creator-ee` was archived August 2024). The image is
pre-pulled during provisioning so task 18 works offline. If the pull fails,
`ansible-navigator --execution-environment false` still works for syntax
checks.

## Practice workflow

```bash
vagrant ssh control
sudo -iu student
# Task 1 asks you to build the inventory and ansible.cfg.
# A reference ansible.cfg is in the repo at files/ansible.cfg.
```

Verify connectivity:

```bash
ansible all -m ping
```

Work the tasks in `lab/tasks/`; check yourself against `lab/solutions/`.

## Snapshots and reset

Provider-specific commands:

```bash
# VirtualBox
VBoxManage snapshot rhce-ansible-control take clean
VBoxManage snapshot rhce-node1           take clean
VBoxManage snapshot rhce-node1           restore clean

# libvirt
sudo virsh snapshot-create-as rhce-ansible-control clean
sudo virsh snapshot-revert    rhce-ansible-control clean

# Parallels
prlctl snapshot rhce-ansible-control -n clean
prlctl snapshot-switch rhce-ansible-control -i <snapshot-id>

# VMware Fusion
vmrun snapshot ".vagrant/machines/control/vmware_desktop/<id>/control.vmx" clean
vmrun revertToSnapshot ".vagrant/machines/control/vmware_desktop/<id>/control.vmx" clean
```

## Override env vars

```bash
LAB_PROVIDER=vmware_desktop vagrant up     # force VMware on a Mac with Parallels too
vagrant up --provider libvirt              # Vagrant's native CLI flag also works
```

## Common commands

```bash
vagrant status
vagrant up [name]
vagrant halt
vagrant ssh control
vagrant destroy -f
```

## Troubleshooting

- **"no provider matches host=..."** — auto-detection didn't match; set
  `LAB_PROVIDER` or `providers.default`.
- **Box variant missing for chosen provider** — verify with
  `curl -s https://app.vagrantup.com/api/v2/box/almalinux/9 | jq '.versions[0].providers[] | {name, architecture}'`.
  Fall back to `almalinux/9.aarch64` on arm64 if needed (edit `box.name` in
  `config.yaml`).
- **NFS `/mnt` not mounted on a node** — `sudo mount -a` (the repo server may
  have provisioned slightly after the node).
- **ansible-navigator EE pull fails** — provisioning continues; run with
  `--execution-environment false` until the image is pulled manually.

## License

MIT — free to use and modify for RHCE preparation.
