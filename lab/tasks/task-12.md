# Task 12 — Set `/etc/issue` by Host Group

Create a playbook that writes a different environment label to `/etc/issue` depending on which host group a node belongs to.

**Playbook path:** `/home/student/ansible/issue.yml`

## Requirements

### a) Target hosts

The playbook must run on **all** inventory hosts.

### b) File content

Replace the entire contents of `/etc/issue` with a single line of text. The text depends on the host's group membership:

| Host group | Content of `/etc/issue` |
|------------|------------------------|
| `dev` | `Development` |
| `test` | `Test` |
| `prod` | `Production` |
