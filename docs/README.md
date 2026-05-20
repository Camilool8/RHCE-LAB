# Documentation

This documentation follows the [Diátaxis framework](https://diataxis.fr/). Pick
the section that matches what you need *right now*:

| If you... | Go to |
|---|---|
| are setting up the lab for the first time | [Tutorial](tutorial/) |
| have a specific task and need the recipe | [How-to guides](how-to/) |
| want to look up an exact value or table | [Reference](reference/) |
| want to understand *why* the lab is built this way | [Explanation](explanation/) |

## Tutorial

Step-by-step lessons. Read these in order if you are new.

- [First run: from zero to `ansible all -m ping`](tutorial/first-run.md)

## How-to guides

Goal-oriented recipes. Each guide solves one problem.

### Setup and lifecycle
- [Install prerequisites for your host OS](how-to/install-prerequisites.md)
- [Start, stop, and reset the lab](how-to/start-stop-reset.md)
- [Snapshot and revert to a clean baseline](how-to/snapshot-and-revert.md)
- [Attach an ISO for offline package mirroring](how-to/attach-iso.md)
- [Change the lab subnet](how-to/change-lab-subnet.md)
- [Use RHEL instead of AlmaLinux with a subscription](how-to/use-rhel-with-subscription.md)

### Daily practice
- [Practice one of the 18 exam tasks](how-to/practice-a-task.md)
- [Use `ansible-navigator`](how-to/use-ansible-navigator.md)
- [Work around the pip-ansible "Illegal instruction" crash](how-to/work-around-ansible-illegal-instruction.md)

### Troubleshooting
- [Troubleshoot the lab network](how-to/troubleshoot-network.md)
- [Troubleshoot a provisioner failure](how-to/troubleshoot-provisioning.md)

## Reference

Authoritative tables. Look up exact values.

- [Provider matrix](reference/provider-matrix.md) — host × provider × plugin
- [Topology](reference/topology.md) — VMs, IPs, RAM, roles
- [Storage layout](reference/storage-layout.md) — per-provider disk device map
- [`config.yaml`](reference/config-yaml.md) — every configuration key
- [Override variables](reference/overrides.md) — `LAB_PROVIDER`, `--provider`
- [Accounts and keys](reference/accounts-and-keys.md) — users, passwords, SSH keys
- [File tree](reference/file-tree.md) — repository layout
- [Exam tasks](reference/tasks.md) — the 18 task / solution files
- [Networking](reference/networking.md) — subnet, firewall zones, NFS exports

## Explanation

Discussion of design decisions.

- [Design overview](explanation/design-overview.md) — the whole lab in one read
- [Native-arch only](explanation/native-arch-only.md) — why no cross-arch emulation
- [In-guest network configuration](explanation/in-guest-network-config.md) — nmcli over Vagrant `auto_config`
- [firewalld zones](explanation/firewalld-zones.md) — `internal` vs `public` vs `trusted`
- [NFS automount](explanation/nfs-automount.md) — systemd automount over `fstab + bg`
- [`ansible-navigator` install paths](explanation/ansible-navigator-install.md) — AAP vs EPEL vs pip
- [Per-provider quirks](explanation/per-provider-quirks.md) — what really differs
