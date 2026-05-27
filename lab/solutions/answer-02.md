## Task 2 — `yum_repository` over the NFS-mounted lab mirror

### What this teaches

- `ansible.builtin.yum_repository` writes `/etc/yum.repos.d/<name>.repo`
  declaratively — idempotent, no `template:` needed for a real repo
  file.
- `file:///mnt/...` URLs work because the lab's repo server NFS-exports
  its mirror to every managed node, and the nodes systemd-automount it
  at `/mnt/BaseOS` and `/mnt/AppStream`. See
  [`docs/explanation/offline-mirror.md`](../../docs/explanation/offline-mirror.md).
- A repo with `enabled: false` is **still defined** — the student can
  install from it with `dnf --enablerepo=BaseOS install foo`. The
  deliverable is the file, not the active state.

### `yum-repo.yml`

```yaml
- name: Configure the BaseOS and AppStream repositories on every node
  hosts: all
  become: true

  vars:
    repos:
      - name: BaseOS
        description: Base OS Repo
        baseurl: file:///mnt/BaseOS/
      - name: AppStream
        description: AppStream Repo
        baseurl: file:///mnt/AppStream/

  tasks:
    - name: Ensure the NFS automount targets exist (touch /mnt/{BaseOS,AppStream})
      ansible.builtin.file:
        path: "/mnt/{{ item }}"
        state: directory
        mode: '0755'
      loop:
        - BaseOS
        - AppStream

    - name: Declare each repository
      ansible.builtin.yum_repository:
        name: "{{ item['name'] }}"
        description: "{{ item['description'] }}"
        baseurl: "{{ item['baseurl'] }}"
        gpgcheck: true
        enabled: false
        gpgkey: file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9
      loop: "{{ repos }}"
      loop_control:
        label: "{{ item['name'] }}"
```

### Run

```bash
ansible-playbook yum-repo.yml
# or, with the exam runner:
ansible-navigator run yum-repo.yml --mode stdout
```

### Verify

```bash
ansible all -b -a 'dnf repolist --all' \
  | grep -E '\b(BaseOS|AppStream)\b'

# Spot-check the file format on node1
ansible node1 -b -a 'cat /etc/yum.repos.d/BaseOS.repo'
```

### Best-practice notes

- **`loop:` with `loop_control.label:`** — one task that writes both
  repos. Cleaner than copy-pasting two `yum_repository` blocks.
- **`gpgcheck: true`** (YAML boolean) instead of `True` (Python-flavored).
  Both work; lowercase is canonical YAML.
- **`become: true`** (YAML), not `become: True`. Same difference.
- The lab's actual offline source on each node is
  `/etc/yum.repos.d/lab-offline.repo` (HTTP), preinstalled by
  `scripts/node/setup-node.sh`. Your task-2 file (`BaseOS.repo`,
  `AppStream.repo`) coexists with it — different filenames, no collision.
