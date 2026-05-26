# Task 5 — Create and Use an Apache Role

Create a custom Ansible role that installs and configures an Apache web server, then write a playbook that applies it.

**Role path:** `/home/student/ansible/roles/apache`

**Playbook path:** `/home/student/ansible/apache-role.yml`

## Requirements

### a) Package and service

- Install the `httpd` package.
- Enable the `httpd` service so it starts on boot.
- Ensure the `httpd` service is started.

### b) Firewall

- The firewall service must be enabled and running.
- Add a permanent rule that allows HTTP traffic through the firewall.

### c) Jinja2 template for the index page

Create the template file `index.html.j2` inside the role.

When rendered, the template must produce `/var/www/html/index.html` on each managed node with the following output:

```
Welcome to HOSTNAME on IPADDRESS
```

Where:

| Placeholder | Ansible fact to use |
|-------------|---------------------|
| `HOSTNAME` | The fully qualified domain name of the managed node |
| `IPADDRESS` | The IP address of the managed node |

### d) Playbook

The playbook `apache-role.yml` must:

- Target hosts in the **`webservers`** host group.
- Apply the `apache` role.
