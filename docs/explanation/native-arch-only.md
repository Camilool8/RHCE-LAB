# Native-arch only

The lab runs guests with the **same** CPU architecture as the host. Apple
Silicon (arm64) Macs run arm64 guests. x86_64 hosts run x86_64 guests. There
is no cross-arch emulation.

## What was tried

An earlier design supported three scenarios:

- A. Native x86_64.
- B. Native arm64.
- C. arm64 host emulating x86_64 guests via QEMU TCG.

Scenario C was attractive because it lets a single AlmaLinux 9 x86_64 box
image work everywhere, and matches the exam environment more literally.

## Why scenario C was dropped

Two hard problems, both upstream:

1. **`vagrant-qemu` silently ignores `config.vm.network`.** The lab depends
   on a private subnet for the seven VMs to reach each other. The
   workaround is `socket_vmnet` (from the Lima project), which requires a
   sudo-installed launchd daemon and an explicit `-netdev socket,fd=3` arg
   in qemu's command line. Documented and supported, but fragile.

2. **AlmaLinux 9 hangs SSH version-banner negotiation under `vagrant-qemu`**
   ([vagrant-qemu issue #67](https://github.com/ppggff/vagrant-qemu/issues/67),
   open since January 2025, no fix). The TCP connection establishes, sshd
   accepts the socket, but the SSH version banner is never sent. Vagrant
   times out waiting and aborts. We hit this on the first attempt with a
   live `vagrant up`.

Both problems compound: even if the network was perfect, the SSH banner
hang blocks `vagrant up` partway through.

## Why we did not work around it

- Switching the box to Rocky 9 might side-step #2, at the cost of losing
  AlmaLinux's exam-realistic conventions.
- Disabling SSH banner timeout would mask other genuine failures.
- Patching `vagrant-qemu` is invasive and breaks on every plugin update.

The lab's purpose is to make practice frictionless, not to fight plugin
bugs. Apple Silicon users have two well-supported native paths
(VMware Fusion or Parallels) and a free third path
(run the lab on any x86_64 Linux host).

## What this means for users

- **macOS Apple Silicon:** install VMware Fusion (free) or Parallels (paid).
  See [How-to: install prerequisites](../how-to/install-prerequisites.md).
- **No Mac hypervisor available:** run the lab on a cloud Linux VM or an
  Intel Mac. Zero code change.
- **Cross-arch testing of x86-specific playbooks:** out of scope. RHCE
  practice does not require it.

## Related

- [Provider matrix](../reference/provider-matrix.md).
- [Per-provider quirks](per-provider-quirks.md).
