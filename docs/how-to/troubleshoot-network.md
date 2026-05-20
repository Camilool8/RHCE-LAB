# Troubleshoot the lab network

Symptom: `ansible all -m ping` fails with `UNREACHABLE`, or
`curl http://192.168.56.40/repo/` from the control node times out, or
NFS automount entries exist on a node but `ls /mnt/BaseOS` fails.

Work through these checks in order.

## Check 1 — Does the lab interface have an IP inside the guest?

```bash
vagrant ssh control -c "ip -4 -br addr"
```

Expected:

```
lo               UNKNOWN        127.0.0.1/8
eth0             UP             172.16.x.x/24      # NAT, used by Vagrant SSH
eth1             UP             192.168.56.50/24   # lab interface
```

- If `eth1` is **missing**: the provider did not attach the second NIC. See
  Check 3 (host-side network device missing).
- If `eth1` is present but `DOWN`: the host-side switch is not bridging
  packets. See Check 3.
- If `eth1` has the wrong IP: re-run the lab-network provisioner:

  ```bash
  vagrant provision control
  ```

## Check 2 — Can the control node ping the repo server?

```bash
vagrant ssh control -c "ping -c 2 192.168.56.40"
```

- 0% loss: the lab subnet works. Move on to Check 4.
- 100% loss: the lab subnet is broken at the host or provider level. See Check 3.

## Check 3 — Is the host's lab-subnet bridge alive?

### VMware Fusion on macOS

```bash
ifconfig | grep -B3 192.168.56
```

Expected: an interface with `inet 192.168.56.1`. On Apple Silicon this is
named `bridge102` (the kernel-level bridge backing vmnet2) — not `vmnet2`.

If nothing matches:

```bash
sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --stop
sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --configure
sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --start
```

Then `vagrant reload --no-provision` so the VMs re-attach.

### Common conflict: `socket_vmnet` from a previous qemu attempt

If you previously experimented with `vagrant-qemu`, the `socket_vmnet`
daemon may be running on the same gateway IP. Check:

```bash
ps -ef | grep socket_vmnet | grep -v grep
```

If anything matches, remove it:

```bash
sudo launchctl unload /Library/LaunchDaemons/com.lima-vm.socket_vmnet.plist
sudo rm /Library/LaunchDaemons/com.lima-vm.socket_vmnet.plist
sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --configure
sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --start
```

### VirtualBox

```bash
VBoxManage list hostonlyifs | grep -A4 vboxnet
```

Re-create the host-only network with `192.168.56.0/24` if missing:

```bash
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1 --netmask 255.255.255.0
```

### libvirt

```bash
sudo virsh net-list --all
sudo virsh net-info default     # or whatever lab network is named
```

If the network is `inactive`, start it:

```bash
sudo virsh net-start <name>
sudo virsh net-autostart <name>
```

## Check 4 — Is firewalld blocking the traffic?

On the repo server:

```bash
vagrant ssh repo -c "sudo firewall-cmd --list-all-zones | grep -A12 internal"
```

Expected: `internal` zone shows `sources: 192.168.56.0/24` and services
include `http`, `nfs`, `mountd`, `rpc-bind`.

If the `internal` zone has no sources, the lab subnet did not get bound.
Re-run:

```bash
vagrant provision repo
```

## Check 5 — Is the NFS server actually exporting?

```bash
vagrant ssh repo -c "sudo exportfs -v && sudo systemctl is-active nfs-server"
```

Expected: two lines for `BaseOS` and `AppStream` plus `active`.

If `nfs-server` is `inactive`:

```bash
vagrant ssh repo -c "sudo systemctl start nfs-server && sudo exportfs -rav"
```

## Check 6 — Trigger and inspect an NFS automount on a node

```bash
vagrant ssh node1 -c "ls /mnt/BaseOS/repodata/repomd.xml && mount | grep /mnt/BaseOS"
```

Expected: the file exists and `mount` shows an `nfs4` line. If `ls` returns
`No such device`, NFS could not reach the repo server — go back to Check 2.

## Related

- [Reference: networking](../reference/networking.md) — full subnet/port/zone map.
- [Explanation: in-guest network configuration](../explanation/in-guest-network-config.md).
