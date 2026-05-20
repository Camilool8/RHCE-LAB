# Networking

## Subnet

The lab subnet is **`192.168.56.0/24`** by default. Change in
[`config.yaml`](config-yaml.md) — see
[How-to: change the lab subnet](../how-to/change-lab-subnet.md).

## IP assignments

| Host                        | IP            |
| --------------------------- | ------------- |
| Host gateway / vmnet bridge | 192.168.56.1  |
| repo-server                 | 192.168.56.40 |
| ansible-control             | 192.168.56.50 |
| node1                       | 192.168.56.51 |
| node2                       | 192.168.56.52 |
| node3                       | 192.168.56.53 |
| node4                       | 192.168.56.54 |
| node5                       | 192.168.56.55 |

## Per-VM interfaces

| Interface | Connected to                           | Configured by                                                                                                            |
| --------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `eth0`    | Provider's NAT network                 | DHCP, on box boot                                                                                                        |
| `eth1`    | Provider's host-only / private network | NetworkManager keyfile (`/etc/NetworkManager/system-connections/lab.nmconnection`) written by `configure-lab-network.sh` |
| `lo`      | loopback                               | n/a                                                                                                                      |

The lab uses `auto_config: false` on `config.vm.network` so Vagrant never
writes any in-guest network configuration — see
[Explanation: in-guest network configuration](../explanation/in-guest-network-config.md).

## firewalld zones

| Zone       | Interface(s) bound | Sources bound                 | Open services                                             |
| ---------- | ------------------ | ----------------------------- | --------------------------------------------------------- |
| `public`   | `eth0` (NAT)       | —                             | `ssh`, `dhcpv6-client`, `cockpit` (default zone defaults) |
| `internal` | `eth1` (lab)       | `192.168.56.0/24` (by source) | varies by VM (see below)                                  |

The lab subnet is bound to `internal` two ways — by interface (via the
NetworkManager keyfile's `connection.zone=internal`) and by source IP (via
`firewall-cmd --add-source`). Either alone would work; both together survive
NetworkManager re-runs and provider-specific interface renames.

### Services open per VM in the `internal` zone

| VM                | Services                                                |
| ----------------- | ------------------------------------------------------- |
| `repo-server`     | `http`, `nfs`, `mountd`, `rpc-bind`                     |
| `ansible-control` | (none beyond defaults — SSH from nodes is not required) |
| `node1`–`node5`   | (none — they are clients only)                          |

## NFS exports (from the repo server)

```
/var/www/html/repo/BaseOS    192.168.56.0/24(ro,sync,no_root_squash)
/var/www/html/repo/AppStream 192.168.56.0/24(ro,sync,no_root_squash)
```

Mount points on each managed node:

| Mount point      | Source                                       | fstab options                                                                                                   |
| ---------------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `/mnt/BaseOS`    | `192.168.56.40:/var/www/html/repo/BaseOS`    | `x-systemd.automount,x-systemd.idle-timeout=600,x-systemd.device-timeout=10,_netdev,nofail,ro,vers=4.2,noatime` |
| `/mnt/AppStream` | `192.168.56.40:/var/www/html/repo/AppStream` | same as above                                                                                                   |

Mounts activate on **first access** (systemd automount), idle out after 10
minutes. See [Explanation: NFS automount](../explanation/nfs-automount.md).

## HTTP services (from the repo server)

| URL                                                 | What                                 |
| --------------------------------------------------- | ------------------------------------ |
| `http://192.168.56.40/repo/BaseOS/`                 | BaseOS package tree + `repodata/`    |
| `http://192.168.56.40/repo/AppStream/`              | AppStream package tree + `repodata/` |
| `http://192.168.56.40/repo/RPM-GPG-KEY-AlmaLinux-9` | Published GPG key                    |

## Forwarded SSH ports (Vagrant NAT)

The provider assigns a unique host port per VM at `vagrant up` time
(starting at `2222` and incrementing on collision). To see the current map:

```bash
vagrant port repo
vagrant port control
```

You should rarely need these — use `vagrant ssh <vmname>` instead.

## Related

- [Provider matrix](provider-matrix.md).
- [Topology](topology.md).
- [Troubleshoot the lab network](../how-to/troubleshoot-network.md).
