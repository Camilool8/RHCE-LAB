# firewalld zones

The lab places the lab subnet (`192.168.56.0/24`) in firewalld's
**`internal`** zone. This is a deliberate choice between three plausible
options.

## firewalld's predefined zones (short version)

From the firewalld project documentation:

| Zone | Trust level | Default behavior |
|---|---|---|
| `public` | low | Only `ssh`, `dhcpv6-client`, `cockpit` accepted. The default zone on most distros. |
| `internal` | medium | "Mostly trusted internal networks." A reasonable default + selected services accepted. |
| `trusted` | absolute | All incoming connections accepted. Firewall effectively off for traffic in this zone. |

## Why `internal`

- **`public`** is the default zone (where `eth0` lives — the NAT interface,
  where SSH from the host arrives). Keeping the lab subnet here would mean
  every NFS / HTTP service we open on the repo server would also be
  accessible from `eth0`. Bad isolation.
- **`trusted`** would work but accepts *all* traffic unconditionally. The
  RHCE exam contains firewalld objectives — students need to practice
  `firewall-cmd --add-service=nfs --zone=...` against a firewall that is
  actually filtering. `trusted` removes that practice surface.
- **`internal`** strikes the right balance: lab-subnet traffic is filtered
  but distinct from the public-facing NAT interface, and students still
  practice firewalld rules.

## How the zone is bound

Two redundant mechanisms — either alone would work; both together are
robust against NetworkManager re-runs and provider interface renames.

### 1. By interface (via NetworkManager keyfile)

`configure-lab-network.sh` sets:

```bash
nmcli connection add ... connection.zone internal
```

NetworkManager stores `zone=internal` in
`/etc/NetworkManager/system-connections/lab.nmconnection`. When NM brings
the interface up, it asks firewalld to place that interface in `internal`.
Survives reboots.

### 2. By source IP

`base-setup.sh` runs:

```bash
firewall-cmd --permanent --zone=internal --add-source=192.168.56.0/24
firewall-cmd --reload
```

Any packet with a source IP in `192.168.56.0/24` is in `internal`,
regardless of which interface it arrives on. This catches edge cases like
a misconfigured interface that ends up in the wrong zone.

## What services are opened where

| Zone | Services |
|---|---|
| `public` (eth0, NAT) | distribution defaults: `ssh`, `dhcpv6-client`, `cockpit` |
| `internal` (192.168.56.0/24) | repo-server adds: `http`, `nfs`, `mountd`, `rpc-bind` |

Other VMs (control, nodes) add nothing to `internal` — they are NFS / HTTP
clients only.

## Inspecting on a running VM

```bash
vagrant ssh repo -c "sudo firewall-cmd --list-all-zones | grep -A12 internal"
```

You should see `192.168.56.0/24` under `sources:` and the four services
under `services:`.

## Related

- [Reference: networking](../reference/networking.md) — full port/service map.
- [In-guest network configuration](in-guest-network-config.md) — how the
  zone gets bound to the interface.
