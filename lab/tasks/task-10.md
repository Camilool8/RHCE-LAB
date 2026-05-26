# Task 10 — Generate `/etc/hosts` Files

Create a Jinja2 template and a playbook that generates a custom hosts file on the `dev` nodes.

**Template path:** `/home/student/ansible/hosts.j2`

**Playbook path:** `/home/student/ansible/gen_hosts.yml`

## Requirements

### a) Create the Jinja2 template

Create `hosts.j2` so that when rendered it produces one line per inventory host in the standard `/etc/hosts` format:

```
IP_ADDRESS  FQDN  SHORT_HOSTNAME
```

### b) Create the playbook

The playbook must:

- Target hosts in the **`dev`** host group.
- Use the `hosts.j2` template to generate the file `/etc/myhosts` on each `dev` node.

### c) Expected output

After the playbook runs, `/etc/myhosts` on the `dev` nodes should contain a line for every managed host, plus the standard localhost entries. Example:

```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.10.x   node1.example.com   node1
192.168.10.y   node2.example.com   node2
192.168.10.z   node3.example.com   node3
192.168.10.a   node4.example.com   node4
192.168.10.b   node5.example.com   node5
```

> The exact IP addresses will match whatever is assigned in your lab environment.
