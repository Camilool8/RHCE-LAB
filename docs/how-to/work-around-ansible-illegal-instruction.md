# Work around the pip-ansible "Illegal instruction" crash

Symptom: `/home/student/.local/bin/ansible all -m ping` exits with:

```
Illegal instruction (core dumped)
```

## Cause

`ansible-dev-tools` was installed via `pip --user` for the `student` user.
On `aarch64` it pulled in a `cryptography` wheel built with CPU instructions
your VM's CPU does not expose. The wheel imports cleanly but crashes when it
first tries to use an unsupported instruction.

## Workaround — use `/usr/bin/ansible`

AlmaLinux 9's appstream repository ships `ansible-core` built against the
distribution's own `cryptography`, which is compiled for the lowest-common-
denominator `aarch64` CPU and works in every VM.

```bash
sudo -iu student
which ansible                # /home/student/.local/bin/ansible (broken)
which /usr/bin/ansible       # /usr/bin/ansible (works)

/usr/bin/ansible all -m ping
```

This is what the EX294 exam uses as well, so writing playbooks against the
distro `ansible-core` is the exam-realistic path.

### Make it the default

Put `/usr/bin` ahead of `/home/student/.local/bin` in `student`'s PATH:

```bash
sudo -iu student
echo 'PATH=/usr/bin:/usr/sbin:$PATH' >> ~/.bashrc
exec bash
```

After this, `ansible`, `ansible-playbook`, `ansible-galaxy` all resolve to the
distro-packaged versions.

## Alternative — run inside the execution environment

`ansible-navigator --execution-environment true` runs everything in the
`community-ansible-dev-tools` container, which has its own `cryptography`
that does not crash:

```bash
ansible-navigator run ~/ansible/task-01.yml --mode stdout
```

See [Use `ansible-navigator`](use-ansible-navigator.md).

## Why we keep the pip install

`ansible-dev-tools` brings `ansible-navigator`, `ansible-creator`,
`ansible-lint`, `molecule`, and `ansible-builder`. Those are useful — the
binary that crashes is specifically the `ansible` entry point. Leaving the
pip install in place keeps the development tools available without breaking
practice runs (which use `/usr/bin/ansible` or the EE image).

## Related

- [Explanation: `ansible-navigator` install paths](../explanation/ansible-navigator-install.md).
