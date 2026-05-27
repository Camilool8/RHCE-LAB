## Task 14 — Create users by job description, from a vault

### What this teaches

- **Reading a vault inside a playbook** via `vars_files:`. No extra
CLI flags needed because `ansible.cfg` has `vault_password_file`.
- **The trap with `password_hash('sha512')`.** Without an explicit
salt, the filter generates a *fresh* random salt every run, which
means a fresh hash, which means the `user` module rewrites the
password every run — non-idempotent. The exam grader applies
playbooks against fresh systems and re-runs them; a non-idempotent
password hash will cost real points.
  - **Solution 1 (preferred):** pass an explicit salt as the second
  arg to `password_hash`. Same input → same hash → idempotent.
  - **Solution 2:** `update_password: on_create`. The hash is still
  random on first creation, but the `user` module won't touch the
  password on subsequent runs.
  - We use **both** — belt-and-suspenders.
- **Per-group user creation** — devs (adam, lucifer) on dev+test,
managers (gabriel) on prod.

### `user_list.yml`

```yaml
---
users:
  - name: adam
    job: developer
    uid: 3000
  - name: gabriel
    job: manager
    uid: 3001
  - name: lucifer
    job: developer
    uid: 3002
```

### `create_user.yml`

```yaml
- name: Create developer accounts on dev + test
  hosts: dev:test
  become: true
  vars_files:
    - vault.yml
    - user_list.yml
  vars:
    # Stable salt -> stable hash -> idempotent re-runs.
    # In a real environment, store the salt in the vault too.
    pwd_salt: rh294salt

  tasks:
    - name: Ensure the 'devops' group exists
      ansible.builtin.group:
        name: devops
        state: present

    - name: Create developer users
      ansible.builtin.user:
        name: "{{ item['name'] }}"
        uid: "{{ item['uid'] }}"
        shell: /bin/bash
        groups: devops
        append: true
        password: "{{ dev_pass | password_hash('sha512', pwd_salt) }}"
        update_password: on_create
        state: present
      loop: "{{ users }}"
      loop_control:
        label: "{{ item['name'] }}"
      when: item['job'] == 'developer'

- name: Create manager accounts on prod
  hosts: prod
  become: true
  vars_files:
    - vault.yml
    - user_list.yml
  vars:
    pwd_salt: rh294salt

  tasks:
    - name: Ensure the 'opsmgr' group exists
      ansible.builtin.group:
        name: opsmgr
        state: present

    - name: Create manager users
      ansible.builtin.user:
        name: "{{ item['name'] }}"
        uid: "{{ item['uid'] }}"
        shell: /bin/bash
        groups: opsmgr
        append: true
        password: "{{ mgr_pass | password_hash('sha512', pwd_salt) }}"
        update_password: on_create
        state: present
      loop: "{{ users }}"
      loop_control:
        label: "{{ item['name'] }}"
      when: item['job'] == 'manager'
```

### Run

```bash
# Host ansible — picks up the vault passwo
ansible-playbook create_user.yml --vault-password-file=./password.txt        # first run: changed=1
ansible-playbook create_user.yml --vault-password-file=./password.txt          # second run: changed=0 failed=0

# Exam runner — see "Why --execution-environment false?" below
ansible-navigator run create_user.yml \
  --vault-password-file=./password.txt \
  --execution-environment false
ansible-navigator run create_user.yml \
  --vault-password-file=./password.txt \
  --execution-environment false
```

### Why `--execution-environment false`?

The `password_hash('sha512', …)` filter is implemented by the
`ansible.builtin.password_hash` plugin, which calls into the Python
`**passlib**` library. That filter runs **inside whichever Python is
executing the playbook** — so when the EE is on, it has to be present
inside the container, not on the host.

The lab's default EE image, `ghcr.io/ansible/community-ansible-dev-tools`,
is a minimal community build that ships `ansible-core` and a handful of
collections but **does not include `passlib`**. With the EE on you get:

```
The filter plugin 'ansible.builtin.password_hash' failed:
Unable to encrypt nor hash, passlib must be installed:
No module named 'passlib'
```

Two workable answers in the lab:

1. **(used here) `--execution-environment false`** — runs against the
  control node's host `ansible-core`, where the provisioner installed
   `python3-passlib` via dnf. Identical behaviour to plain
   `ansible-playbook`.
2. **Build a custom EE** that layers `passlib` on top of the community
  image (`ansible-builder` + a small `execution-environment.yml`).
   Correct but heavy for a single filter.

**On the real EX294 exam this is a non-issue.** The exam uses
`registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9:latest`,
the Red Hat-supported EE, which bundles `passlib` (and `jmespath`,
`netaddr`, `pywinrm`, the system-roles collection, etc.) out of the
box. There you leave `execution-environment: true` and run:

```bash
ansible-navigator run create_user.yml --vault-password-file=./password.txt
```

### Verify

```bash
ansible dev,test -b -m shell -a 'id adam lucifer; getent shadow adam | cut -d: -f2 | head -c 3'
# adam: $6$   (SHA512)

ansible prod -b -m shell -a 'id gabriel; getent shadow gabriel | cut -d: -f2 | head -c 3'
# gabriel: $6$

# Try logging in as adam from the control node — the password is the
# vault's dev_pass value
sshpass -p redhat ssh -o StrictHostKeyChecking=no adam@node1 whoami
```

### Best-practice notes

- **The salt is the headline fix.** `password_hash('sha512', 'rh294salt')`
is fully deterministic — the second `ansible-playbook` run reports
`changed=0` even though the `user` module compares the new hash
against the on-disk one.
- `**update_password: on_create`** belts-and-suspenders the
idempotency. Even if some future refactor removes the explicit salt,
the password won't churn.
- **Two plays** for two scopes (dev+test vs prod) — cleaner than one
play with three `when:` conditions, and the second play gathers
facts only on the smaller prod group.
- `**vars_files:`** automatically decrypts the vault — `ansible.cfg`'s
`vault_password_file` does the rest.
- `**loop_control.label:**` keeps the output readable
(`item={'name': 'adam', 'uid': 3000, ...}` is a wall of YAML).
- `**groups: …` + `append: true**` — the user gets the supplementary
group on top of any existing memberships. Without `append`, every
supplementary group not in the list would be revoked.

