# Task 17 — Create and Use Partitions

Create a playbook that partitions the extra data disk on every managed node and mounts it on `prod` nodes.

**Playbook path:** `/home/student/ansible/partition.yml`

## Requirements

### a) Target hosts

The playbook must run on **all** managed nodes.

### b) Discover the raw data disk at runtime

Each managed node has one additional unpartitioned data disk attached. **Do not hard-code the device path** — the exact name differs by hypervisor (e.g. `/dev/sdb`, `/dev/vdb`, `/dev/nvme0n2`).

Discover the disk at runtime using `ansible_facts.devices`:

- Filter to entries that have **no existing partitions**.
- Exclude the OS root disk.

### c) Create a partition

On the discovered disk:

- Create a **primary partition**, partition number **1**.
- Requested size: **1200 MiB**.
- Format the partition as **ext4**.

### d) Mount on `prod` nodes

On hosts in the **`prod`** host group only:

- Permanently mount the new partition at `/srv`.
- The mount must survive a reboot (add an entry to `/etc/fstab`).

### e) Size fallback

If a `1200 MiB` partition cannot be created:

1. Print the message: `Could not create partition of that size`
2. Create an **800 MiB** partition instead.

### f) Missing disk

If no unpartitioned data disk is found on a node:

- Print the message: `this disk does not exist`
- Skip partitioning on that node.

---

> **Hint:** `ansible_facts.devices` is a dict keyed by short device name (e.g. `vdb`). Each value contains a `partitions` dict (empty for raw disks) and a `size` string. Use these fields to identify the correct target disk.
