# Use RHEL instead of AlmaLinux with a subscription

The default box is `almalinux/9`, which is free and behaves identically to
RHEL 9 for the purposes of the EX294 exam. If you have an active **Red Hat
Developer subscription** (free at <https://developers.redhat.com>) or a paid
Red Hat subscription, you can swap to a true RHEL box so the control node
sees `subscription-manager` and the Ansible Automation Platform (AAP)
repository becomes available.

## Step 1 — Find a RHEL 9 Vagrant box for your provider

Red Hat publishes RHEL Vagrant boxes via [HCP Vagrant Registry](https://portal.cloud.hashicorp.com/vagrant/discover/generic).
On Apple Silicon you specifically need an `aarch64` variant — the most reliable
multi-provider source is `generic/rhel9` (check
`https://app.vagrantup.com/api/v2/box/generic/rhel9` for current provider
variants).

## Step 2 — Edit `config.yaml`

```yaml
box:
  name: "generic/rhel9"     # was "almalinux/9"
```

## Step 3 — Destroy and rebuild

```bash
vagrant destroy -f
rm -rf disks/
vagrant up
```

The first `vagrant up` will download the new box.

## Step 4 — Register the control node

```bash
vagrant ssh control
sudo subscription-manager register --username=<your-user> --password=<your-pass>
sudo subscription-manager attach --auto
```

## Step 5 — Confirm the AAP repo is enabled

The lab's `setup-control.sh` detects an active subscription and enables
`ansible-automation-platform-2.5-for-rhel-9-$(uname -m)-rpms` automatically
during provisioning. Verify:

```bash
sudo subscription-manager repos --list-enabled \
  | grep ansible-automation-platform
```

Then re-run the control-node provisioner so it picks up the freshly-available
AAP packages:

```bash
exit                                     # back to host
vagrant provision control
```

`ansible-navigator` is now installed from the AAP RPM rather than via pip —
no `oniguruma-devel` build, no Rust compile.

## Step 6 — Use the official Red Hat execution environment

The lab's default EE is the community image (`community-ansible-dev-tools`).
To use Red Hat's official AAP EE on a subscribed system:

```bash
vagrant ssh control
sudo -iu student
podman login registry.redhat.io       # use your Red Hat credentials
podman pull registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9:latest
```

Edit `~/.ansible-navigator.yml`:

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

## Caveats

- **Red Hat's AAP EE images are only published for `amd64`** on the Red Hat
  Ecosystem Catalog. On Apple Silicon (arm64) you must stay on the community
  EE image. The lab defaults to the community image for exactly this reason.
- **The free developer subscription has a 16-system entitlement limit.** Each
  destroy/up cycle re-registers fresh systems unless you also run
  `subscription-manager unregister` before destroying.
