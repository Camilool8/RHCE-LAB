# Provider matrix

The Vagrantfile picks a provider based on the host OS and CPU architecture
(`RbConfig::CONFIG['host_os']` and `host_cpu`). Override with
[`LAB_PROVIDER`](overrides.md) or `vagrant up --provider`.

## Auto-selected provider

The Vagrantfile **probes for installed hypervisors** before falling back to
a per-host default. You only need to set `LAB_PROVIDER` (or
`providers.default` in `config.yaml`) if the auto-detected provider is not
the one you want to use.

| Host OS | Host arch | First choice if installed | Fallback if first not present | Final fallback |
|---|---|---|---|---|
| macOS Intel | `x86_64` | VirtualBox (`/Applications/VirtualBox.app`) | VMware Fusion (`/Applications/VMware Fusion.app`) | `virtualbox` |
| macOS Apple Silicon | `arm64` | Parallels (`/Applications/Parallels Desktop.app`) | VMware Fusion (`/Applications/VMware Fusion.app`) | `parallels` |
| Linux | `x86_64` / `arm64` | libvirt (`virsh` in PATH) | VirtualBox (`VBoxManage` in PATH) | `libvirt` |
| Windows | `x86_64` | VirtualBox | — | `virtualbox` |

So, for example: a fresh Apple Silicon Mac with **only** VMware Fusion installed
will auto-select `vmware_desktop` — no env var needed. The same Mac with
Parallels installed will pick `parallels`. With both installed, Parallels
wins (paid, native acceleration is the preferred choice on arm64).

## Required plugins by provider

| Provider | Plugin | Install |
|---|---|---|
| `virtualbox` | — (built-in) | none |
| `libvirt` | `vagrant-libvirt` | `vagrant plugin install vagrant-libvirt` |
| `parallels` | `vagrant-parallels` | `vagrant plugin install vagrant-parallels` |
| `vmware_desktop` | `vagrant-vmware-desktop` + Vagrant VMware Utility | `brew install --cask vagrant-vmware-utility` then `vagrant plugin install vagrant-vmware-desktop` |

## Fallback providers (manually selected)

Any of these is supported via `LAB_PROVIDER=<name>`:

| Provider | Works on | Notes |
|---|---|---|
| `vmware_desktop` | macOS, Linux, Windows | Free for personal use post-Broadcom. The lab's primary choice on Apple Silicon Macs without Parallels. |
| `virtualbox` | macOS Intel, Linux, Windows | Not usable on macOS Apple Silicon (no x86_64 guest support). |
| `libvirt` | Linux only | Cleanest, fastest on Linux. |
| `parallels` | macOS only | Paid. Pro / Business edition required for Vagrant integration. |

## Explicitly unsupported

| Provider | Reason |
|---|---|
| `hyperv` | Silently ignores `config.vm.network` — the lab requires a private subnet. |
| `qemu` (vagrant-qemu) | No `config.vm.network` support; AlmaLinux 9 boot + SSH banner bug (vagrant-qemu issue #67). |
| `utm` (vagrant_utm) | No documented `private_network`; no AlmaLinux box in the gallery. |
| `vmware_desktop` for x86 guests on Apple Silicon | Fusion 13 does not emulate x86 (Broadcom KB 315602). |

## Related

- [Override variables](overrides.md) — `LAB_PROVIDER`, `vagrant up --provider`.
- [Explanation: native-arch only](../explanation/native-arch-only.md).
- [Explanation: per-provider quirks](../explanation/per-provider-quirks.md).
