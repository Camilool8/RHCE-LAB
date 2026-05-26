# Task 11 — Generate a Hardware Report

Create a playbook that collects hardware facts from all managed nodes and writes them to a report file on each node.

**Playbook path:** `/home/student/ansible/hwreport.yml`

**Output file (on each node):** `/root/hwreport.txt`

## Requirements

### a) Target hosts

The playbook must run on **all** managed nodes.

### b) Collected information

Each line in `/root/hwreport.txt` must be a `KEY=value` pair. The file must contain the following three entries:

| Key | Value |
|-----|-------|
| `INVENTORY_HOSTNAME` | The inventory hostname of the managed node |
| `TOTAL_MEMORY_IN_MB` | Total memory of the node in MB |
| `BIOS_VERSION` | The BIOS version string |

### c) Example output

```
INVENTORY_HOSTNAME=node-hostname
TOTAL_MEMORY_IN_MB=1024
BIOS_VERSION=2.1.2
```
