# Accounts and keys

## User accounts

Every VM (repo, control, all five nodes) has these accounts:

| User      | Password  | Sudo         | Purpose                                                                |
| --------- | --------- | ------------ | ---------------------------------------------------------------------- |
| `student` | `1234`    | passwordless | RHCE practice user. Every EX294 task path hard-codes `/home/student/`. |
| `redhat`  | `redhat`  | passwordless | Convenience admin shell, mirrors the RHCSA-LAB convention.             |
| `vagrant` | `vagrant` | passwordless | Default Vagrant user. Used by `vagrant ssh`.                           |
| `root`    | (locked)  | n/a          | Use `sudo` from `student` or `redhat` instead.                         |

`student` is created by `scripts/common/create-users.sh` and is the user the
RHCE practice tasks expect.

## SSH keys

### `RH294-LAB` — control → managed-node practice key

A 2048-bit RSA keypair generated on the **host** during the first
`vagrant up`. Lives at:

```
files/keys/RH294-LAB         # private (host)
files/keys/RH294-LAB.pub     # public (host)
```

The Vagrantfile uploads:

- The **private** key to the control node at
  `/home/student/.ssh/RH294-LAB` (mode 600, owned by `student`).
- The **public** key to each managed node, appended to
  `/home/student/.ssh/authorized_keys` (mode 600).

The reference `ansible.cfg` in `files/ansible.cfg` references the key:

```ini
[defaults]
private_key_file = ~/.ssh/RH294-LAB
```

### Vagrant's insecure key — host → any VM

Used by `vagrant ssh`. Stored in `~/.vagrant.d/insecure_private_key` on the
host and `~/.ssh/authorized_keys` for the `vagrant` user inside the VM. Not
relevant to RHCE practice.

## Re-generating the `RH294-LAB` key

If you want to force a fresh keypair:

```bash
rm -f files/keys/RH294-LAB files/keys/RH294-LAB.pub
vagrant provision        # re-runs all provisioners; key is re-generated on next up
```

`files/keys/` is in `.gitignore` — the key never enters version control.

## Editor configuration

The control node gets a copy of `files/vimrc` at `/home/student/.vimrc`. It
sets RHCE-friendly defaults plus a `<Leader>K` mapping to show
`ansible-doc` for the module under the cursor.

## Related

- [Topology](topology.md).
- [Networking](networking.md) — port/service map.
