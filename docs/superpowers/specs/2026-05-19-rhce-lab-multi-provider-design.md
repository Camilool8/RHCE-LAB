# RHCE-LAB Multi-Provider Design (Spec Amendment)

**Date:** 2026-05-19
**Status:** Approved (revised 2026-05-19: dropped x86-emulation scenario)
**Amends:** [2026-05-19-rhce-lab-design.md](./2026-05-19-rhce-lab-design.md)

## Purpose

Extend RHCE-LAB so a single repo runs **native-arch only** across the major
host OSes, instead of being VirtualBox + x86_64 only.

- **A. Native x86_64** — host and guest both x86_64. Hardware acceleration.
- **B. Native arm64** — host and guest both arm64 (Apple Silicon, Linux arm64).
  Hardware acceleration.

A cross-arch "scenario C" (arm64 host emulating x86_64 guests via QEMU TCG)
was attempted and removed. The vagrant-qemu plugin's combination of silently-
ignored `config.vm.network`, no first-class extra-disks API, mandatory
`socket_vmnet` plumbing, and an unfixed AlmaLinux 9 SSH-banner hang
(vagrant-qemu issue #67) made it unviable. Apple Silicon users without
Parallels or VMware should run the lab on a Linux x86_64 host instead.

## Goals

- A single `vagrant up` works on macOS (Intel and Apple Silicon), Linux
  (x86_64 and arm64), and Windows x86_64 — without per-host forks of the repo.
- Auto-detect the right provider for the host; env-var or CLI override for
  any explicit choice.
- All 18 RHCE tasks remain runnable end-to-end regardless of provider
  (private subnet, two extra disks per managed node, optional ISO attach).
- Document the one-time prerequisites for each provider in the README.

## Non-Goals

- Cross-architecture emulation (arm64 host running x86_64 guests, or vice
  versa). Native-arch only.
- Hyper-V — silently ignores `config.vm.network`, can't deliver the private
  subnet the lab depends on.
- `vagrant_utm` — no AlmaLinux box, no documented `private_network`, snapshots
  unsupported.
- `vagrant-qemu` — even native-arm64 use hits hard plugin limitations
  (`config.vm.network` ignored, brittle SSH startup on AlmaLinux 9).
- Parallels' Intel-emulator on Apple Silicon — capped at 1 vCPU / 8 GB, can't
  fit 7 VMs.
- VMware Fusion on Apple Silicon for x86_64 guests — Broadcom KB 315602
  confirms Fusion supports arm64 guests only on Apple Silicon.

## Provider matrix

Primary recommendations are auto-selected; VMware is a documented fallback.

| Scenario | Host | Primary | Fallback |
|---|---|---|---|
| A. Native x86_64 | macOS Intel | `virtualbox` | `vmware_desktop` |
| A. Native x86_64 | Linux x86_64 | `libvirt` | `virtualbox` |
| A. Native x86_64 | Windows | `virtualbox` | `vmware_desktop` |
| B. Native arm64 | macOS Apple Silicon | `parallels` | `vmware_desktop` |
| B. Native arm64 | Linux arm64 | `libvirt` (kvm) | — |

Plugins required (the Vagrantfile checks for their presence and prints
installation instructions if missing):
- `vagrant-libvirt` — Linux (any scenario)
- `vagrant-parallels` — macOS Apple Silicon
- `vagrant-vmware-desktop` — any host using the VMware fallback
- `virtualbox` — no plugin (built into Vagrant)

## Provider selection logic

The Vagrantfile determines the provider in this order:

1. `vagrant up --provider <name>` (Vagrant's native flag) wins if given. The
   Vagrantfile scans ARGV directly so the override is honoured even at the
   config phase, not just at machine-action time.
2. Else `ENV['LAB_PROVIDER']` wins if set.
3. Else `providers.default` from `config.yaml` if non-empty.
4. Else look up `(host_os, host_arch)` in the matrix above.

`host_os` is detected via `RbConfig::CONFIG['host_os']` (matches `/darwin/`,
`/linux/`, `/mingw|mswin|cygwin/`). `host_arch` via `RbConfig::CONFIG['host_cpu']`
(normalized: `x86_64`, `arm64`).

The chosen provider and architecture are logged on every `vagrant up` so it
is always obvious what's in effect:

```
==> RHCE-LAB: host=macos/arm64 provider=parallels box_arch=arm64
```

## `config.yaml` changes

Add a top-level `providers:` section. Per-VM RAM/CPU stay where they are.

```yaml
providers:
  # Auto-detection picks one from (host_os, host_arch). Override here
  # (e.g. "vmware_desktop") or with LAB_PROVIDER env var to pin a provider.
  default: ""

  virtualbox:     { enabled: true }
  libvirt:        { enabled: true, network_name: "rhce-lab" }
  parallels:      { enabled: true }
  vmware_desktop: { enabled: true }
```

`box: { name: "almalinux/9" }` stays as-is. `almalinux/9` is multi-arch
multi-provider; Vagrant picks the correct variant based on the chosen provider
and `config.vm.box_architecture` (set by the Vagrantfile from the host arch).

## Vagrantfile architecture

The Vagrantfile gets a small Ruby helper layer that encapsulates per-provider
differences so each VM definition stays readable:

- `detect_host_os`, `detect_host_arch` — RbConfig wrappers.
- `detect_cli_provider` — scans ARGV for `--provider X` / `--provider=X`.
- `PROVIDER_MATRIX` constant — the table above as a Ruby hash.
- `lab_apply_basics(m, vm_cfg, vm_name)` — memory, CPU, naming for each
  provider.
- `lab_private_network(m, ip)` — standard `config.vm.network "private_network"`
  for all four providers.
- `lab_attach_extra_disk(m, vm_name, idx, size_gb)` — per-provider extra-disk
  syntax (`config.vm.disk` for VirtualBox/VMware, `libvirt.storage :file` for
  libvirt, `prl.customize ... --device-add hdd` for Parallels).
- `lab_attach_iso(m, iso_path)` — per-provider ISO attach syntax.

### Per-provider cheat-sheet (the helpers wrap these)

| Concern | virtualbox | libvirt | parallels | vmware_desktop |
|---|---|---|---|---|
| Memory/CPU | `vb.memory` / `vb.cpus` | `libvirt.memory` / `libvirt.cpus` | `prl.memory` / `prl.cpus` | `v.vmx["memsize"]` / `v.vmx["numvcpus"]` |
| Private subnet | `config.vm.network "private_network", ip:` | same | same | same |
| Extra disk | `config.vm.disk :disk, size:` | `libvirt.storage :file, size:` | `prl.customize ["set", :id, "--device-add", "hdd", "--size",...]` | `config.vm.disk :disk, size:` |
| ISO attach | `config.vm.disk :dvd, file:` | `libvirt.storage :file, device: :cdrom, path:` | `prl.customize ["set", :id, "--device-set", "cdrom0", "--image",...]` | `config.vm.disk :dvd, file:` |

On arm64 Linux libvirt uses `cpu_mode = 'host-passthrough'` (KVM on arm64
doesn't accept `host-model` reliably). Everywhere else the libvirt defaults
are sufficient.

## Networking

Every supported provider implements `config.vm.network "private_network"`
natively, so the lab's 192.168.56.0/24 subnet is delivered by Vagrant without
any in-guest configuration. The original VirtualBox-era provisioning order
applies unchanged.

## Per-provider extra-disks and ISO

The helper functions invoke each provider's native disk API directly,
including `config.vm.disk` (VirtualBox, VMware) and `libvirt.storage :file`
(libvirt). Parallels uses
`prl.customize ["set", :id, "--device-add", "hdd", "--size", "<MB>"]`.

ISO auto-detection (a single file matched by `iso/*.iso`) stays in the
Vagrantfile and routes through `lab_attach_iso(m, iso_path)`.

## Box and arch selection

- Default box: `almalinux/9`. Multi-provider, multi-arch per AlmaLinux's
  Packer template.
- `host_arch = x86_64` ⇒ `config.vm.box_architecture = "amd64"`.
  `host_arch = arm64` ⇒ `config.vm.box_architecture = "arm64"`.

If a Vagrant-Cloud lookup ever returns no matching variant for the host arch,
Vagrant prints a clear error referencing the missing combination.

## Provisioning scripts

The existing eight scripts (`base-setup.sh`, `create-users.sh`,
`setup-repos.sh`, `setup-nfs.sh`, `setup-gpg.sh`, `setup-node.sh`,
`setup-control.sh`) are guest-side and provider-agnostic; they stay
**unchanged**. `setup-node.sh` already detects either `/dev/sdc` (SCSI/SATA)
or `/dev/vdc` (virtio) so the `research` VG is built correctly on every
provider.

## File-level changes (relative to the original lab)

| Path | Change |
|---|---|
| `config.yaml` | Add `providers:` section |
| `Vagrantfile` | Refactor — provider auto-selection + helper functions + per-provider blocks |
| `README.md` | Major rewrite of the prerequisites + scenarios + one-time host setup |

The provisioning scripts under `scripts/common/`, `scripts/repo-server/`,
`scripts/node/`, `scripts/control/` are **untouched**.

## Acceptance criteria

- Auto-selection chooses the right provider on each (host_os, host_arch)
  tuple, with `LAB_PROVIDER` / `vagrant up --provider` overrides honored.
- `vagrant up` completes on each supported scenario where the corresponding
  hypervisor + plugin is installed on the host.
- On every supported provider: `ansible all -m ping` from the control node
  succeeds against all five managed nodes.
- Tasks 16 and 17 still have the right disks (`/dev/sd*` or `/dev/vd*` —
  scripts probe for both) and the `research` VG.
- `iso/*.iso` is recognised and mounted on every provider.
- README documents the one-time install/setup commands per provider, the env
  variables for explicit selection, and the known constraints.

## Open follow-ups (not blocking)

- Confirm `vagrant box add --provider libvirt --arch aarch64 almalinux/9`
  resolves at build time on arm64 Linux hosts; if not, fall back to the
  legacy `almalinux/9.aarch64` box.
- A future enhancement could surface `LAB_PROVIDER` as a friendly CLI flag
  on the upcoming `bin/rhce-lab` wrapper (Plan B / Grading & Exam Tooling).
- Apple Silicon users without Parallels Desktop or VMware Fusion currently
  have no native-arm64 path. VMware Fusion is free for personal use post-
  Broadcom; this is the recommended install for those users.
