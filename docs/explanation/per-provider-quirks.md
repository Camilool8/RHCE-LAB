# Per-provider quirks

The four supported providers each have a few specific behaviors the lab
works around. This page documents what those are, so a maintainer porting
the lab knows what to expect.

## VirtualBox

| Concern             | Behavior                                                                                                                       | Lab response                                                                        |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| Extra disks         | Native `config.vm.disk :disk, size:` works directly.                                                                           | Use the high-level Vagrant disk DSL.                                                |
| Lab subnet          | Host-only network, native `private_network` works (with `auto_config: false` because of AlmaLinux's ifcfg-removal).            | `lab_private_network` helper, `configure-lab-network.sh` in-guest.                  |
| Box availability    | `almalinux/9` ships a `virtualbox` provider variant for both `amd64` and `arm64` (the arm64 build is for non-Apple ARM hosts). | None.                                                                               |
| Apple Silicon hosts | VirtualBox 7.1+ runs on macOS arm64 but cannot run x86_64 guests.                                                              | Provider is _not_ auto-selected on Apple Silicon — use Fusion or Parallels instead. |

## libvirt (Linux only)

| Concern          | Behavior                                                               | Lab response                                                               |
| ---------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Acceleration     | Native KVM. Fastest of the four on Linux.                              | `lv.driver = 'kvm'`.                                                       |
| arm64 KVM        | `cpu_mode = 'host-model'` is unreliable on KVM/aarch64.                | `lv.cpu_mode = 'host-passthrough'` when `HOST_ARCH == 'arm64'`.            |
| Extra disks      | `libvirt.storage :file, size:, bus: 'virtio'` (provider-specific API). | `lab_attach_extra_disk` libvirt branch.                                    |
| Device names     | virtio block devices appear as `/dev/vd[a-z]`.                         | `setup-node.sh` probes `/dev/vdc` along with `/dev/sdc`.                   |
| Lab subnet name  | libvirt requires a named network.                                      | `config.yaml` `providers.libvirt.network_name: rhce-lab` controls this.    |
| User permissions | The user running `vagrant up` must be in the `libvirt` group.          | Documented in [Install prerequisites](../how-to/install-prerequisites.md). |

## Parallels Desktop (macOS only)

| Concern                          | Behavior                                                                                                      | Lab response                                 |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| Licensing                        | Standard edition does not expose `prlctl` to Vagrant.                                                         | Documented requirement: **Pro or Business**. |
| Extra disks                      | No native Vagrant `config.vm.disk` capability; use `prl.customize` with `prlctl set --device-add hdd --size`. | `lab_attach_extra_disk` parallels branch.    |
| Device names                     | Disks appear as `/dev/sd[a-z]` (SATA).                                                                        | `setup-node.sh` probes `/dev/sdc`.           |
| Intel emulation on Apple Silicon | Capped at 1 vCPU / 8 GB / no nested virt — unfit for a 7-VM lab.                                              | Lab is native-arm64 on Apple Silicon.        |
| Box availability                 | `almalinux/9` publishes a `parallels` aarch64 variant.                                                        | None.                                        |

## VMware Fusion (macOS, free for personal use)

| Concern                                        | Behavior                                                                                                                                                                                                                                              | Lab response                                                                  |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Extra disks default to SCSI lsilogic           | `vmrun` on Apple Silicon rejects `scsi0.virtualDev = "lsilogic"`.                                                                                                                                                                                     | Disks declared with `vmware_desktop: { bus_type: 'nvme' }`.                   |
| Device names                                   | NVMe devices appear as `/dev/nvme0n[1-]`.                                                                                                                                                                                                             | `setup-node.sh` probes `/dev/nvme0n3` for the research VG.                    |
| Host vmnet must be running                     | `vmnet1`, `vmnet2`, `vmnet8` interfaces need to exist on the host.                                                                                                                                                                                    | Documented as a one-time setup step: `sudo vmnet-cli --configure && --start`. |
| `vmnet2` shows as `bridge102` on Apple Silicon | The kernel device backing Fusion's vmnet is a `bridge*` interface, not `vmnet*`.                                                                                                                                                                      | Documented in [troubleshoot-network.md](../how-to/troubleshoot-network.md).   |
| `vagrant-vmware-utility`                       | Required separate launchd daemon.                                                                                                                                                                                                                     | Documented install (`brew install --cask vagrant-vmware-utility`).            |
| Apple Silicon + x86 guests                     | Fusion 13 does not emulate x86 (Broadcom KB 315602).                                                                                                                                                                                                  | Lab is native-arm64 on Apple Silicon.                                         |
| Plugin nil-filename bug                        | vagrant-vmware-desktop 3.0.5 iterates disk entries including DVD slots with `nil` filenames; if a `nil` filename slot exists, `File.extname` throws `TypeError`. We did not hit this on the final NVMe-only path but reserved a workaround if needed. | None at present; tracked in upstream issue history.                           |

## Explicitly excluded providers

| Provider       | Why not                                                                                                                                                                 |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `hyperv`       | Silently ignores all `config.vm.network` settings. Lab cannot deliver the private subnet.                                                                               |
| `vagrant_utm`  | No documented `private_network` support, snapshots experimental, AlmaLinux 9 not in box gallery.                                                                        |
| `vagrant-qemu` | Silently ignores `config.vm.network`; requires `socket_vmnet` and custom vmx for inter-VM networking; AlmaLinux 9 SSH banner hang under qemu (open upstream issue #67). |

## Related

- [Provider matrix](../reference/provider-matrix.md).
- [Storage layout](../reference/storage-layout.md).
- [Design overview](design-overview.md).
