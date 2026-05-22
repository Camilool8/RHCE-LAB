# Use `ansible-navigator`

`ansible-navigator` is the official Red Hat tool for running Ansible content
in an execution environment. It is the tool used in the EX294 exam.

The lab installs `ansible-navigator` on the control node and pre-pulls the
community execution environment image
(`ghcr.io/ansible/community-ansible-dev-tools:latest`).

## Confirm it works

```bash
vagrant ssh control
sudo -iu student
ansible-navigator --version
```

You should see `ansible-navigator 26.4.0` (or whatever the pip-installed
version is at provisioning time).

## Run a playbook in EE mode (recommended)

```bash
ansible-navigator run ~/ansible/task-01.yml --mode stdout
```

What this does:

- Spawns the `community-ansible-dev-tools` container.
- Mounts your home directory into the container.
- Runs the playbook with the container's `ansible-core`.

Drop the `--mode stdout` to get the full TUI (text user interface) instead of
plain text output.

## Run without the execution environment

When you do not want a container — for example you are debugging a Python
dependency on the host:

```bash
ansible-navigator run ~/ansible/task-01.yml --execution-environment false --mode stdout
```

This uses the **host's** `ansible-core` (the one installed by `dnf` — on
aarch64 often `/usr/local/bin/ansible`, otherwise `/usr/bin/ansible`). It is
the same engine that `ansible-playbook` uses, so the result is identical to
running `ansible-playbook` directly.

## Inspect the EE image

```bash
podman images | grep dev-tools
podman run --rm ghcr.io/ansible/community-ansible-dev-tools:latest \
       ansible --version
```

## Use a different EE image

Edit `/home/student/.ansible-navigator.yml`:

```yaml
---
ansible-navigator:
  execution-environment:
    enabled: true
    image: registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9:latest
    pull:
      policy: missing
    container-engine: podman
```

For Red Hat's official EE images you need a Red Hat subscription and to
`podman login registry.redhat.io` first. See [Use RHEL with subscription](use-rhel-with-subscription.md).

## Common warnings to ignore

These appear under `podman` running as `student` and are harmless:

```
WARN: The cgroupv2 manager is set to systemd but there is no systemd user session available
WARN: Falling back to --cgroup-manager=cgroupfs
```

If you want them gone, enable lingering for the student user:

```bash
sudo loginctl enable-linger student
```

## Related

- [Work around the pip-ansible "Illegal instruction" crash](work-around-ansible-illegal-instruction.md) — why we recommend EE mode or the distro `ansible` on `PATH`.
- [Explanation: `ansible-navigator` install paths](../explanation/ansible-navigator-install.md).
