## Task 5 — A custom `apache` role + playbook for `webservers`

### What this teaches

- The **standard Ansible role layout** (`tasks/`, `templates/`,
  `handlers/`, `vars/`, `defaults/`, `meta/`). `ansible-galaxy role
  init` scaffolds it.
- **Handlers** for "restart on config change" — the canonical way to
  bounce a service only when something it depends on actually moved.
- **Idempotent service + firewall + template** combo: each module is
  idempotent on its own, and together they reach a steady state on the
  first run.
- **FQCN modules** (`ansible.builtin.dnf`, `ansible.posix.firewalld`)
  so the play runs under an execution environment cleanly.

### Prerequisites

```bash
ansible-galaxy collection install ansible.posix -p ./mycollection/
```

### Scaffold the role

```bash
ansible-galaxy role init apache --init-path=./roles/
```

### `roles/apache/defaults/main.yml`

```yaml
---
apache_packages:
  - httpd
  - firewalld
apache_firewall_services:
  - http
  - https
```

(`defaults/` instead of `vars/` so a caller can override at play time.)

### `roles/apache/tasks/main.yml`

```yaml
---
- name: Install httpd and firewalld
  ansible.builtin.dnf:
    name: "{{ apache_packages }}"
    state: present

- name: Ensure firewalld and httpd are enabled at boot and running
  ansible.builtin.service:
    name: "{{ item }}"
    state: started
    enabled: true
  loop: "{{ apache_packages }}"

- name: Open the web ports in firewalld (runtime + persistent)
  ansible.posix.firewalld:
    service: "{{ item }}"
    state: enabled
    permanent: true
    immediate: true
  loop: "{{ apache_firewall_services }}"

- name: Render the per-host welcome page
  ansible.builtin.template:
    src: index.html.j2
    dest: /var/www/html/index.html
    owner: root
    group: root
    mode: '0644'
  notify: Reload httpd
```

### `roles/apache/handlers/main.yml`

```yaml
---
- name: Reload httpd
  ansible.builtin.service:
    name: httpd
    state: reloaded
```

### `roles/apache/templates/index.html.j2`

```jinja
Welcome to {{ ansible_facts['fqdn'] }} on {{ ansible_facts['default_ipv4']['address'] }}
```

(Plain text, single line — matches the task spec exactly.)

### `apache-role.yml`

```yaml
- name: Deploy the apache role to the webservers group
  hosts: webservers
  become: true
  roles:
    - role: apache
```

### Run

```bash
ansible-playbook apache-role.yml
# or, with the exam runner:
ansible-navigator run apache-role.yml --mode stdout
```

### Verify

```bash
# Per-host welcome page rendered with the right hostname + IP
ansible webservers -b -m shell -a "curl -s http://localhost"

# Firewall is open
ansible webservers -b -m shell -a "firewall-cmd --list-services"

# httpd is enabled for next boot
ansible webservers -b -a "systemctl is-enabled httpd"
```

### Best-practice notes

- **`state: present`** for the packages — the task doesn't ask for the
  *latest* httpd, just that it's installed. Keeps the role idempotent.
- **`notify: Reload httpd`** — when the template changes (e.g. the
  hostname or IP changes), the handler bounces the service. On the
  first run the service is already started+enabled by the previous
  task, so the handler runs as a `reloaded` no-op; on subsequent
  runs after a template change it's the only thing that fires.
- **Default vars in `defaults/main.yml`**, not `vars/main.yml`.
  Defaults can be overridden by play-level vars, group_vars, host_vars,
  or `--extra-vars`; the same key in `vars/` cannot. Always start in
  defaults and only move to vars if you have a reason.
- **`ansible.posix.firewalld` with `immediate: true` AND
  `permanent: true`** — runtime and on-disk state both updated, so the
  rule survives a reboot AND is live now. Reference exam grader will
  reboot and re-check, so persistence matters.
- **`ansible_facts['fqdn']`** — the FQDN form. The lab's `/etc/hosts`
  on each node lists the host as `nodeN.example.com`, so this resolves
  to e.g. `node3.example.com`.
