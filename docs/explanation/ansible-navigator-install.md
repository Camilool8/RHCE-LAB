# `ansible-navigator` install paths

The lab tries three install paths in order, falling through on failure. The
order matters — preferred paths are the most exam-realistic and the most
robust.

## Path 1 — RHEL + active subscription (preferred)

```bash
subscription-manager status
subscription-manager repos --enable=ansible-automation-platform-2.5-for-rhel-9-$(uname -m)-rpms
dnf install -y ansible-navigator
```

This is what the **EX294 exam environment ships**. If a user runs the lab
on a true RHEL box with a working subscription, the lab takes this path
automatically and `ansible-navigator` lands in `/usr/bin/`. No pip, no
source build.

Caveats:

- AlmaLinux 9 has no subscription system, so this path is skipped on the
  default box.
- The AAP `aarch64` repo exists, but Red Hat's **EE images** for
  `aarch64` may not be published — see "EE image choice" below.

## Path 2 — Distro-packaged from EPEL

```bash
dnf install -y epel-release
dnf install -y ansible-navigator
```

EPEL packages `ansible-navigator` for AlmaLinux 9. This avoids the source
build entirely. The lab attempts this path if subscription-manager is
absent or unsubscribed.

Caveats:

- EPEL's `ansible-navigator` may lag a release or two behind PyPI.
- Some EPEL aarch64 builds have been missing in the past.

## Path 3 — pip install of `ansible-dev-tools`

```bash
dnf install -y \
  python3.11 python3.11-pip python3.11-devel \
  gcc make libffi-devel openssl-devel krb5-devel \
  oniguruma-devel              # from EPEL+CRB
runuser -l student -c 'python3.11 -m pip install --user ansible-dev-tools'
```

The pip install pulls in `ansible-navigator`, `ansible-creator`,
`ansible-lint`, `ansible-builder`, `molecule`, and the full dev-tools
constellation. `ansible-dev-tools` requires Python ≥ 3.10 — AlmaLinux 9's
platform Python is 3.9, so we explicitly use `python3.11`.

The build deps cover:

- `gcc`, `python3.11-devel`, `libffi-devel`, `openssl-devel` → `cffi`,
  `cryptography` builds.
- `krb5-devel` → optional Kerberos auth wheels.
- `oniguruma-devel` → `onigurumacffi` build. This package is in EPEL's
  CRB (CodeReady Builder) repository, which the lab enables explicitly.

### The "Illegal instruction" trap

The pip-installed `cryptography` wheel for aarch64 sometimes uses CPU
instructions not exposed by the lab's VMs. The resulting `ansible` binary
runs `Illegal instruction (core dumped)` on first use. The lab does not
attempt to "fix" this wheel — instead it documents the workaround
([Work around the pip-ansible "Illegal instruction" crash](../how-to/work-around-ansible-illegal-instruction.md))
and recommends `/usr/bin/ansible` (from `dnf install ansible-core`) for
regular ansible commands. `ansible-navigator` itself is fine because its
real work runs inside the execution-environment container.

## EE image choice

The lab pre-pulls
**`ghcr.io/ansible/community-ansible-dev-tools:latest`**.

Why this image:

- Public — no `podman login` required.
- Multi-arch — published for both `amd64` and `arm64`.
- Maintained — the official "use this image as your EE" recommendation in
  the [Ansible Development Tools documentation](https://docs.ansible.com/projects/dev-tools/).

Why **not** `quay.io/ansible/creator-ee`:

- **Archived August 2024.** The repository's README explicitly redirects
  users to `community-ansible-dev-tools`.

Why **not** `registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9`:

- Requires `podman login` with Red Hat credentials.
- The Red Hat Ecosystem Catalog as of the lab's last research run lists the
  image only for `amd64` — there is no aarch64 variant. On Apple Silicon you
  would not be able to pull it natively.

If you have a subscription and want the Red Hat EE on an amd64 host, see
[How-to: use RHEL with subscription](../how-to/use-rhel-with-subscription.md).

## Related

- [Use ansible-navigator](../how-to/use-ansible-navigator.md).
- [Work around the pip-ansible "Illegal instruction" crash](../how-to/work-around-ansible-illegal-instruction.md).
