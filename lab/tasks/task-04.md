# Task 4 — Configure Time Synchronisation

Use the RHEL system roles to configure NTP time synchronisation across all managed nodes.

**Playbook path:** `/home/student/ansible/timesync.yml`

## Requirements

### a) Install the system roles package

Install the `rhel-system-roles` package on the control node before writing the playbook.

### b) Target hosts

The playbook must run on **all** managed hosts.

### c) Use the `timesync` role

Apply the `timesync` role provided by `rhel-system-roles`.

### d) Role configuration

| Variable | Value |
|----------|-------|
| Time server | `172.25.254.250` |
| `iburst` parameter | `enabled` (`true`) |
