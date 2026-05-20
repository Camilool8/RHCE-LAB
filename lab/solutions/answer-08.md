## Task 8 — Setgid directory + symlink + content on the test group

### What this teaches

- **The setgid bit on a directory** (`2xxx` mode): files created
  inside inherit the directory's group instead of the creator's
  primary group. Useful for shared-team directories.
- **Symbolic links** with `ansible.builtin.file: state=link`. The
  `src:` is the *target*, the `dest:` is the *link itself*.
- **Idempotent file content** with `ansible.builtin.copy: content:`.
  `lineinfile` works too, but `copy: content:` is the right tool
  when you control the whole file.

### Direction of the symlink

The task says "Symbolically link `/var/www/html/webtest` to `/webtest`."
The natural reading — and what the verifier checks — is that
`/var/www/html/webtest` is the *link* and `/webtest` is the *target*:

```
/var/www/html/webtest  -->  /webtest
```

Reversing it (making `/webtest` itself the symlink) would clobber the
setgid directory you just created.

### `test.yml`

```yaml
- name: Configure /webtest on the test group
  hosts: test
  become: true

  tasks:
    - name: Ensure the 'webtest' group exists
      ansible.builtin.group:
        name: webtest
        state: present

    - name: Create /webtest as a setgid dir owned by group 'webtest'
      ansible.builtin.file:
        path: /webtest
        state: directory
        group: webtest
        # 2: setgid;  7=u:rwx  7=g:rwx  5=o:r-x  -> exactly what the task asks.
        mode: '2775'

    - name: Write /webtest/index.html
      ansible.builtin.copy:
        dest: /webtest/index.html
        content: "Testing.\n"
        mode: '0644'

    - name: Ensure /var/www/html exists (so the symlink has a parent)
      ansible.builtin.file:
        path: /var/www/html
        state: directory
        mode: '0755'

    - name: Symlink /var/www/html/webtest -> /webtest
      ansible.builtin.file:
        src: /webtest
        dest: /var/www/html/webtest
        state: link
        force: true
```

### Run

```bash
ansible-playbook test.yml
```

### Verify

```bash
ansible test -b -a 'stat -c "%a %A %G" /webtest'
# expect: 2775 drwxrwsr-x webtest

ansible test -b -m shell -a 'readlink /var/www/html/webtest'
# expect: /webtest

ansible test -b -a 'cat /var/www/html/webtest/index.html'
# expect: Testing.
```

### Best-practice notes

- **`content: "Testing.\n"`** (with explicit `\n`) — `copy: content:`
  writes exactly the bytes you give it, so a missing trailing newline
  becomes a real difference on disk. Be explicit.
- **`force: true` on the symlink** lets the link replace anything
  pre-existing at `dest:` (e.g. a stale directory from an earlier
  attempt). Without it, the task fails when `dest` already exists as
  something other than the desired link.
- **`mode: '2775'`** is a string, not the integer 2775. YAML parses
  unquoted `2775` as decimal 2775 — wrong octal. Always quote modes.
- **No httpd needed.** node2 (the test group) doesn't run a web
  server in this lab; we create `/var/www/html` ourselves only so the
  symlink has a parent directory.
