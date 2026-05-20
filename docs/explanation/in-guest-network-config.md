# In-guest network configuration

The lab uses `nmcli` inside each guest to assign the lab IP — Vagrant's
`config.vm.network` declaration carries `auto_config: false`, so Vagrant
does not touch the guest.

## What Vagrant normally does

`config.vm.network "private_network", ip: "192.168.56.50"` would normally
trigger Vagrant's RedHat guest capability to write
`/etc/sysconfig/network-scripts/ifcfg-eth1` inside the VM with the IP, and
restart the network service. This has worked since Vagrant gained the
RedHat guest capability years ago.

## Why it stopped working

AlmaLinux 9.6 (and RHEL 9.6) **removed the `ifcfg-*` reader from
NetworkManager**. NetworkManager now uses keyfile format in
`/etc/NetworkManager/system-connections/*.nmconnection` instead. The
ifcfg files Vagrant writes are silently ignored — the IP never gets
assigned.

This is HashiCorp Vagrant
[issue #13744](https://github.com/hashicorp/vagrant/issues/13744), open as
of the lab's last refresh. The same bug affects all four providers
(`virtualbox`, `libvirt`, `parallels`, `vmware_desktop`) — it is a
guest-OS-level Vagrant bug, not provider-specific.

## What the lab does instead

In the Vagrantfile:

```ruby
m.vm.network "private_network", ip: ip, netmask: MASK, auto_config: false
```

`auto_config: false` tells Vagrant: "do create the host-side network and
attach a NIC, but do not touch the guest."

In `scripts/common/configure-lab-network.sh`:

```bash
nmcli connection add type ethernet \
  con-name lab \
  ifname "$LAB_IF" \
  ipv4.method manual \
  ipv4.addresses "${IP}/${NETMASK_BITS}" \
  ipv6.method disabled \
  connection.autoconnect yes \
  connection.zone internal
```

This writes a keyfile that NetworkManager actually reads, with three
non-obvious settings:

- `connection.autoconnect yes` — survive reboots.
- `connection.zone internal` — bind the interface to firewalld's `internal`
  zone via the NM↔firewalld dispatcher, persistent across reboots.
- `ipv6.method disabled` — the lab has no IPv6; disabling avoids slow
  duplicate-address-detection delays on boot.

## Interface name detection

The script does not assume `eth1`. It picks the first interface that is
**not**:

- `lo`,
- `virbr*` or `docker*` (libvirt / container bridges),
- the default route's interface (always the NAT NIC).

AlmaLinux 9's boxes ship with `net.ifnames=0 biosdevname=0` on the kernel
cmdline, so the lab interface is reliably `eth1`. The detection logic is
defensive for future-distro changes.

## Why not just fix Vagrant?

The lab's own scope is RHCE practice, not contributing to upstream Vagrant.
A patched Vagrant version would not help the user without packaging it.
The in-guest workaround is simpler, robust, and lives in code the lab
controls.

## Related

- [firewalld zones](firewalld-zones.md) — why `internal` and not `public`.
- [Reference: networking](../reference/networking.md) — full IP / zone map.
- [Troubleshoot the lab network](../how-to/troubleshoot-network.md).
