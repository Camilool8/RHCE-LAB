# Task 16 — Create and Use a Logical Volume

Create a playbook that provisions a logical volume on all managed nodes, with graceful error handling when the volume group or required size is not available.

**Playbook path:** `/home/student/ansible/lvm.yml`

## Requirements

### a) Target hosts

The playbook must run on **all** managed nodes.

### b) Logical volume specification

| Setting | Value |
|---------|-------|
| Volume group | `research` |
| Logical volume name | `data` |
| Requested size | `1200 MiB` |
| Filesystem | `ext4` |

### c) Size fallback

If a `1200 MiB` logical volume cannot be created (e.g. insufficient space):

1. Display the message: `could not create logical volume of that size`
2. Create the logical volume at **`800 MiB`** instead.

### d) Missing volume group

If the `research` volume group does not exist on a node:

- Display the message: `volume group does not exist`
- Skip logical volume creation on that node.

### e) Do not mount

Do **not** mount the logical volume or add it to `/etc/fstab`.
