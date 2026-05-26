# Task 15 — Configure Cron Jobs

Create a playbook that schedules a recurring cron job on all managed nodes.

**Playbook path:** `/home/student/ansible/cron.yml`

## Requirements

### a) Target hosts

The playbook must run on **all** managed nodes in the inventory.

### b) Cron job specification

| Setting | Value |
|---------|-------|
| Schedule | Every **2 minutes** |
| Command | `logger "EX294 exam in progress"` |
| Run as user | `natasha` |
