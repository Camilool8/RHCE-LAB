# RHCE-LAB Multi-Provider Design (Spec Amendment)

**Date:** 2026-05-19
**Status:** Approved
**Amends:** [2026-05-19-rhce-lab-design.md](./2026-05-19-rhce-lab-design.md)

## Purpose

Extend RHCE-LAB so a single repo runs on three host scenarios across the major
host OSes, instead of being VirtualBox + x86_64 only.

- **A. Native x86_64** — host and guest both x86_64. Hardware acceleration.
- **B. Native arm64** — host and guest both arm64 (Apple Silicon, Linux arm64).
  Hardware acceleration.
- **C. arm64 host emulating x86_64** — Apple Silicon or Linux arm64 running
  x86_64 guests via QEMU TCG software emulation.

The original spec listed "KVM/libvirt or VMware support" and "Apple Silicon" as
non-goals. This amendment supersedes that.

## Goals

- Single `vagrant up` works on macOS (Intel and Apple Silicon), Linux (x86_64
  and arm64), and Windows x86_64 — without per-host forks of the repo.
- Auto-detect the right provider for the host; env-var or CLI override for
  scenario C and any explicit choice.
- All 18 RHCE tasks remain runnable end-to-end regardless of provider
  (private subnet, two extra disks per managed node, optional ISO attach).
- Document the one-time prerequisites for each provider in the README.

## Non-Goals

- Hyper-V — silently ignores `config.vm.network`, can't deliver the private
  subnet the lab depends on.
- `vagrant_utm` — no AlmaLinux box, no documented `private_network`, snapshots
  unsupported.
- Parallels' Intel-emulator on Apple Silicon — capped at 1 vCPU / 8 GB,
  documented as "early tech preview"; can't fit 7 VMs.
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
| C. arm64 → x86 | macOS Apple Silicon | `qemu` + `socket_vmnet` | — |
| C. arm64 → x86 | Linux arm64 | `libvirt` (qemu/tcg) | — |

Plugins required (the Vagrantfile checks for their presence and prints
installation instructions if missing):
- `vagrant-libvirt` — Linux (any scenario)
- `vagrant-parallels` — macOS Apple Silicon, scenario B
- `vagrant-qemu` — macOS Apple Silicon, scenario C
- `vagrant-vmware-desktop` — any host using the VMware fallback
- `virtualbox` — no plugin (built into Vagrant)

## Provider selection logic

The Vagrantfile determines the provider in this order:

1. `vagrant up --provider <name>` (Vagrant's native flag) wins if given.
2. Else `ENV['LAB_PROVIDER']` wins if set.
3. Else look up `(host_os, host_arch, lab_arch)` in the matrix above, where
   `lab_arch = ENV['LAB_ARCH'] || host_arch`. Setting `LAB_ARCH=x86_64` on an
   arm64 host selects scenario C.

`host_os` is detected via `RbConfig::CONFIG['host_os']` (matches `/darwin/`,
`/linux/`, `/mingw|mswin|cygwin/`). `host_arch` via `RbConfig::CONFIG['host_cpu']`
(normalized: `x86_64`, `arm64`/`aarch64`).

The chosen provider and `lab_arch` are logged on every `vagrant up` so it's
always obvious what's in effect.

## `config.yaml` changes

Add a top-level `providers:` section. Per-VM RAM/CPU stay where they are.

```yaml
providers:
  # Optional explicit pin — leave blank to use auto-selection.
  default: ""

  virtualbox: { enabled: true }
  libvirt:    { enabled: true, network_name: "rhce-lab" }
  parallels:  { enabled: true }
  vmware_desktop: { enabled: true }

  qemu:
    enabled: true
    # Paths used on macOS Apple Silicon scenario C. Overridable.
    socket_vmnet_client: "/opt/homebrew/opt/socket_vmnet/bin/socket_vmnet_client"
    socket_vmnet_socket: "/opt/homebrew/var/run/socket_vmnet"
    qemu_system_x86_64:  "/opt/homebrew/bin/qemu-system-x86_64"
    qemu_system_aarch64: "/opt/homebrew/bin/qemu-system-aarch64"
```

`box: { name: "almalinux/9" }` stays as-is. `almalinux/9` is multi-arch
multi-provider; Vagrant picks the correct variant based on the chosen provider
and `config.vm.box_architecture` (set by the Vagrantfile from `lab_arch`).

## Vagrantfile architecture

The Vagrantfile gets a small Ruby helper module that encapsulates per-provider
differences so each VM definition stays readable. Two reasonable shapes:

- Inline `case provider` blocks within each VM (simpler, more lines).
- Helper functions: `lab_apply_provider(machine, provider, vm_cfg, role)`,
  `lab_attach_disk(machine, provider, path, size_gb)`,
  `lab_attach_iso(machine, provider, iso_path)`,
  `lab_private_network(machine, provider, ip)`.

We use the helper-functions form — it keeps each VM definition four or five
lines and centralises the provider quirks in one place. The helpers live at
the top of the Vagrantfile (the repo doesn't need a separate `lib/` package).

### Per-provider syntax cheat-sheet (the helpers wrap these)

| Concern | virtualbox | libvirt | parallels | qemu | vmware_desktop |
|---|---|---|---|---|---|
| Memory/CPU | `vb.memory` / `vb.cpus` | `libvirt.memory` / `libvirt.cpus` | `prl.memory` / `prl.cpus` | `qe.memory` / `qe.smp` | `v.vmx["memsize"]` / `v.vmx["numvcpus"]` |
| Private subnet | `config.vm.network "private_network", ip:` | same | same | **not supported** — see below | same |
| Extra disk | `config.vm.disk :disk, size:` | `libvirt.storage :file, size:` | `prl.customize ["set", :id, "--device-add", "hdd", "--size",...]` | pre-create qcow2 + `qe.extra_qemu_args` with `-drive` | `v.vmx["scsi0:N.fileName"]` |
| ISO attach | `config.vm.disk :dvd, file:` | `libvirt.storage :file, device: :cdrom, path:` | `prl.customize ["set", :id, "--device-set", "cdrom0", "--image",...]` | `qe.extra_qemu_args = %W(-drive file=#{iso},media=cdrom)` | `v.vmx["ide0:1.fileName"]` |
| Cross-arch (Scenario C) | n/a | `libvirt.driver = "qemu"; libvirt.machine_arch = "x86_64"; libvirt.emulator_path = "/usr/bin/qemu-system-x86_64"` | n/a (Parallels emulator unfit) | `qe.arch = "x86_64"; qe.machine = "q35"; qe.cpu = "qemu64"` | n/a |

## Networking under `qemu` (Apple Silicon Scenario C)

`vagrant-qemu 0.3.12` silently ignores `config.vm.network`. The only viable
multi-VM path is `socket_vmnet` (from the Lima project), wired in via the
plugin's `qe.qemu_bin` array option (added in PR #73, May 2025).

**One-time host setup** (codified in `scripts/host/setup-socket-vmnet.sh`):

```bash
brew install socket_vmnet
sudo brew services start socket_vmnet
```

By default, socket_vmnet runs in shared mode with subnet `192.168.105.0/24`.
The lab's subnet must match. Two ways to align them:

1. **Recommended:** Configure socket_vmnet for `192.168.56.0/24` by editing its
   launchd plist to pass `--vmnet-gateway=192.168.56.1`. The setup script does
   this idempotently.
2. **Alternative:** Change `network.subnet` in `config.yaml` to `192.168.105`.
   Less invasive on the host but rewires every IP reference.

We go with option 1 — the setup script writes a plist override under
`~/Library/LaunchAgents/com.lima-vm.socket_vmnet.plist` (or the brew-managed
location), stops/starts the service, and verifies the daemon is listening on
the configured socket. Idempotent on re-run.

**IP assignment in-guest.** socket_vmnet's DHCP can be MAC-reserved, but the
plist-based interface is fragile across socket_vmnet versions. We sidestep it:
each VM gets a fixed MAC via `qe.extra_qemu_args` and runs an early
provisioning script (`scripts/common/configure-static-ip.sh`) that uses
`nmcli` to set the lab IP, gateway, and DNS on the lab interface. This script
runs first in the provisioner chain on every provider (idempotent — when
`config.vm.network` already assigned the right IP, the script is a no-op).

## Per-provider extra-disks and ISO

`scripts/host/precreate-disks.sh` (only used under `qemu`) generates two
`qcow2` files per managed node in `disks/` before the VM boots, using a
Vagrant `trigger.before :up`. Sizes come from `config.yaml`.

For the other providers, the helper functions invoke each provider's native
disk API directly, including `config.vm.disk` (VirtualBox, VMware) and
`libvirt.storage :file` (libvirt). Parallels uses
`prl.customize ["set", :id, "--device-add", "hdd", "--size", "<MB>"]`.

ISO auto-detection (a single file matched by `iso/*.iso`) stays in the
Vagrantfile and routes through `lab_attach_iso(machine, provider, iso_path)`.
Under `qemu` the ISO is attached read-only via `-drive media=cdrom`.

## Box and arch selection

- Default box: `almalinux/9`. Multi-provider, multi-arch per AlmaLinux's
  Packer template.
- `lab_arch = x86_64` ⇒ `config.vm.box_architecture = "amd64"`. `lab_arch =
  arm64` ⇒ `config.vm.box_architecture = "arm64"`.
- `qemu` provider consumes the `libvirt` variant of `almalinux/9` (vagrant-qemu
  is documented to accept libvirt-format boxes, with libvirt-only directives
  ignored).

If a Vagrant-Cloud lookup ever returns no matching variant, the Vagrantfile
prints a specific error referencing the missing combination.

## Provisioning scripts

The existing eight scripts (`base-setup.sh`, `create-users.sh`,
`setup-repos.sh`, `setup-nfs.sh`, `setup-gpg.sh`, `setup-node.sh`,
`setup-control.sh`) are guest-side and provider-agnostic; they stay
**unchanged** except for the addition of `configure-static-ip.sh` as a new
early step on every VM. The helper for that script accepts the target IP,
gateway, and DNS as arguments and uses `nmcli` to set them on the lab
interface — only making changes when the active config differs.

## File-level changes (relative to the original lab)

| Path | Change |
|---|---|
| `config.yaml` | Add `providers:` section |
| `Vagrantfile` | Refactor — provider auto-selection + helper functions + per-provider blocks |
| `scripts/host/setup-socket-vmnet.sh` | **New** — one-time macOS Apple Silicon host setup for scenario C |
| `scripts/host/precreate-disks.sh` | **New** — pre-creates qcow2 disks for qemu provider |
| `scripts/common/configure-static-ip.sh` | **New** — idempotent in-guest nmcli IP config |
| `README.md` | Major rewrite of the prerequisites + scenarios + one-time host setup |
| `.gitignore` | Add `disks/*.qcow2`, `files/keys/` already present |
| `iso/README.md` | Note that ISO attach is supported on all providers (qemu mounts read-only via `-drive media=cdrom`) |

The provisioning scripts under `scripts/common/`, `scripts/repo-server/`,
`scripts/node/`, `scripts/control/` are **untouched**.

## Acceptance criteria

- Auto-selection chooses the right provider on each (host_os, host_arch,
  lab_arch) tuple, with `LAB_PROVIDER` / `LAB_ARCH` / `vagrant up --provider`
  overrides honored.
- `vagrant up` completes on each supported scenario where the corresponding
  hypervisor + plugin is installed on the host.
- On every supported provider: `ansible all -m ping` from the control node
  succeeds against all five managed nodes.
- Tasks 16 and 17 still have the right disks (`/dev/sd*` or `/dev/vd*` —
  scripts probe for both) and the `research` VG.
- `iso/*.iso` is recognised and mounted on every provider.
- README documents the one-time install/setup commands per provider, the env
  variables for explicit selection, and the known constraints (socket_vmnet,
  TCG performance, etc.).

## Open follow-ups (not blocking)

- On Apple Silicon, the existing `setup-node.sh` references `/dev/sdc` for the
  `research` VG. Under libvirt/qemu the device name will be `/dev/vdc`. The
  script must accept either; this is a small change captured in the plan.
- Confirm `vagrant box add --provider libvirt --arch aarch64 almalinux/9`
  resolves at build time; if not, fall back to the legacy
  `almalinux/9.aarch64` box.
- A future enhancement could surface `LAB_PROVIDER` / `LAB_ARCH` as friendly
  CLI flags on the upcoming `bin/rhce-lab` wrapper (Plan B / Grading & Exam
  Tooling).
