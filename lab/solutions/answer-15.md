## Task 15 — Cron job as `natasha`, every 2 minutes

### What this teaches

- **`ansible.builtin.cron`** maintains user-level `crontab` entries
  idempotently. The `name:` field is the key — it becomes a comment
  marker in the crontab, which is how the module finds the entry on
  re-runs.
- **Creating the user as a side effect** of the playbook. The task
  doesn't mention `natasha` *should exist*; it just specifies that the
  cron runs as her. The right interpretation is to make the playbook
  self-contained.
- **`crontab -l -u natasha`** reads `/var/spool/cron/natasha`, the
  user crontab. Don't confuse with `/etc/cron.d/`, which is the
  system-cron location with a different file format (the user is in
  field 6).

### `cron.yml`

```yaml
- name: Set up natasha's recurring logger
  hosts: all
  become: true

  vars:
    cron_user: natasha
    cron_message: "EX294 exam in progress"

  tasks:
    - name: Ensure user 'natasha' exists
      ansible.builtin.user:
        name: "{{ cron_user }}"
        shell: /bin/bash
        state: present

    - name: Schedule the logger every 2 minutes
      ansible.builtin.cron:
        name: "EX294 logger every 2 min"
        user: "{{ cron_user }}"
        minute: "*/2"
        job: 'logger "{{ cron_message }}"'
        state: present
```

### Run

```bash
ansible-playbook cron.yml
```

### Verify

```bash
ansible all -b -a 'crontab -l -u natasha'
# */2 * * * * logger "EX294 exam in progress"

# After a few minutes — the message lands in the journal
ansible all -b -m shell -a 'journalctl -t natasha --since "5 min ago" -o cat | tail -5'
```

### Best-practice notes

- **`logger`** writes to `journald` on RHEL 9 (rsyslog is no longer
  installed by default). Use `journalctl -t <tag>` to read it, not
  `/var/log/messages` (which exists only if you installed rsyslog).
- **`name:` is the dedup key.** Picking a stable name like
  "EX294 logger every 2 min" makes the cron entry's identity stable —
  rename it, and Ansible adds a *new* entry instead of updating the
  old one.
- **No `cron_file:`** — the task asks for `crontab -l -u natasha` to
  show the entry. `cron_file:` writes to `/etc/cron.d/<file>` instead,
  where it's user-attributed differently (field 6) and *not* visible
  to `crontab -l`.
- **`state: present`** is the default for `ansible.builtin.cron`;
  declaring it makes intent clear and lets you switch to `absent` for
  cleanup with one edit.
- **`shell: /bin/bash`** on `natasha` — required for any future
  `ssh natasha@…` interactive logins. Without it she gets `/sbin/nologin`.
