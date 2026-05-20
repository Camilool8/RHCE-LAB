# Change the lab subnet

The default lab subnet is `192.168.56.0/24`. Change it if you have a conflict
with another VirtualBox / Fusion / libvirt private network on your host.

## Step 1 — Edit `config.yaml`

```yaml
network:
  subnet: "192.168.66"     # was "192.168.56"
  netmask: "255.255.255.0"
```

The `subnet` value is the **first three octets** only. Per-VM IPs are derived
from it:

- `repo_server.ip` is set explicitly (default `192.168.56.40`). Edit to match.
- `control.ip` is set explicitly (default `192.168.56.50`). Edit to match.
- Node IPs are computed: `{subnet}.{nodes.base_ip + i - 1}`. The default
  `base_ip: 51` gives node1 = `.51` through node5 = `.55`. Edit `base_ip` if
  needed.

So if you change `subnet` to `192.168.66`, also update:

```yaml
vms:
  repo_server:
    ip: "192.168.66.40"     # match new subnet
  control:
    ip: "192.168.66.50"
```

## Step 2 — Destroy and rebuild

The lab subnet is wired into the firewalld zones, NFS exports, and the
control node's `/etc/hosts`. The cleanest way to apply a subnet change is to
rebuild:

```bash
vagrant destroy -f
rm -rf disks/
vagrant up
```

Provisioning re-reads `config.yaml` and uses the new subnet everywhere.

## VMware Fusion only — also update vmnet2

If you use Fusion on Apple Silicon, the host-side vmnet2 device serves the
old subnet's gateway (`192.168.56.1` by default). Reconfigure it:

```bash
sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --stop
# Edit /Library/Preferences/VMware\ Fusion/networking to change vmnet2's
# HOSTONLY_SUBNET, then:
sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --configure
sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --start
```

If you do not change vmnet2's subnet, the VMs' `eth1` will not have a
network to attach to and the lab subnet will be unreachable.

## Verify

```bash
vagrant ssh control -c "ip -4 -br addr show eth1"
# Expect: eth1   UP   192.168.66.50/24
```

## Related

- [Reference: networking](../reference/networking.md) — what IPs are used where.
- [Troubleshoot the lab network](troubleshoot-network.md) — when the subnet doesn't come up.
