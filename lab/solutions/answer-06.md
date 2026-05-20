## Task 6 — Install three Galaxy roles from URLs via `requirements.yml`

### What this teaches

- **`requirements.yml`** is the declarative way to pin role dependencies
  for a project — like `Gemfile` or `requirements.txt` for Ansible.
  Check it into Git; everyone installs the same versions.
- **`name:` + `src:`** lets you rename a role on install. The upstream
  tarball is `mafalb-squid-0.2.0.tar.gz` but you reference it as `squid`
  in playbooks. This is how vendored role names stay stable across
  upstream renames.
- The same file can carry both `roles:` and `collections:` blocks —
  newer projects mix both.

### `roles/requirements.yml`

```yaml
---
roles:
  - name: zabbix
    src: https://galaxy.ansible.com/download/zabbix-zabbix-1.0.6.tar.gz
  - name: security
    src: https://galaxy.ansible.com/download/openafs_contrib-openafs-1.9.0.tar.gz
  - name: squid
    src: https://galaxy.ansible.com/download/mafalb-squid-0.2.0.tar.gz

# Also pull the collections we need elsewhere in this exam — task 5 uses
# ansible.posix.firewalld, task 16 uses community.general.lvol,
# task 17 uses ansible.posix.mount + community.general.parted.
collections:
  - name: community.general
  - name: ansible.posix
```

### Install

```bash
ansible-galaxy install -r roles/requirements.yml -p ./roles/
# (collections go to collections_path from ansible.cfg — ./mycollection)
ansible-galaxy collection install -r roles/requirements.yml -p ./mycollection/
```

(or in one shot: `ansible-galaxy install -r roles/requirements.yml` and
let `ansible.cfg`'s `roles_path` + `collections_path` route them.)

### Verify

```bash
ansible-galaxy role list -p ./roles
ansible-galaxy collection list -p ./mycollection
ls ./roles/{zabbix,security,squid}
```

### Best-practice notes

- **Pin versions** (`version: 1.0.6`) when the source supports it.
  Tarball URLs already embed the version, so this is a moot point here,
  but for `src: <git URL>` always set `version:` to a tag or commit.
- **One file, two blocks.** `requirements.yml` carries both `roles:`
  and `collections:` — install both with the same `-r` flag. Real
  projects almost always need both.
- **The `mafalb.squid` role is orphaned** in its Galaxy namespace (the
  author dropped it; the artifact persists in storage). It still works.
  If you ever need a maintained alternative, `geerlingguy.squid` is the
  drop-in replacement; just change the `src:` URL and keep
  `name: squid` so task 7's playbook still works unchanged.
- **`curl -L` (GET) on the tarball URL works**; `curl -I` (HEAD)
  returns 403 because Galaxy NG uses single-use pre-signed S3 URLs for
  the actual download. Don't put HEAD-only checks in CI.
