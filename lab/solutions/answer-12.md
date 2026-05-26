## Task 12 — Per-group `/etc/issue`

### What this teaches

- **A single task that branches on group membership** beats three
  near-identical tasks. The pattern: a `vars:` dict mapping group →
  value, plus a Jinja expression that picks the value from
  `group_names`.
- **`copy: content:` with explicit `\n`** — needed for idempotency.
  Without the trailing newline, `copy` writes a no-newline file, but
  many tools append `\n` on save, so the next run reports `changed=1`
  because the on-disk file no longer matches.

### `issue.yml`

```yaml
- name: Set /etc/issue per host group
  hosts: dev:test:prod
  become: true

  vars:
    issue_text:
      dev: Development
      test: Test
      prod: Production

  tasks:
    - name: Pick the message for this host
      ansible.builtin.set_fact:
        my_issue: >-
          {{ (group_names | intersect(issue_text.keys() | list) | first) }}

    - name: Write /etc/issue
      ansible.builtin.copy:
        dest: /etc/issue
        content: "{{ issue_text[my_issue] }}\n"
        owner: root
        group: root
        mode: '0644'
```

### Run

```bash
ansible-playbook issue.yml
# or, with the exam runner:
ansible-navigator run issue.yml --mode stdout
```

### Verify

```bash
ansible dev  -b -a 'cat /etc/issue'   # Development
ansible test -b -a 'cat /etc/issue'   # Test
ansible prod -b -a 'cat /etc/issue'   # Production
ansible balancers -b -a 'cat /etc/issue'  # unchanged (default \S)
```

### Best-practice notes

- **`hosts: dev:test:prod`** — the colon-separated pattern is the
  in-line union. The play simply doesn't run on the balancers group,
  no `when:` needed.
- **`set_fact` once, use everywhere** — avoids repeating the
  `group_names | intersect(...) | first` expression in every task that
  needs the per-host value.
- **`>-` (folded block scalar, strip-newline)** — keeps the long
  Jinja expression readable across lines without sneaking a `\n` into
  the resulting fact.
- **`content: "{{ value }}\n"`** — `copy: content:` writes exactly the
  bytes you give it. Always finish with `\n` so the file matches what
  text-mode editors produce.
