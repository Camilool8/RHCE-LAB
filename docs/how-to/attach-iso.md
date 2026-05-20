# Attach an ISO for offline package mirroring

By default the repo server's `BaseOS` and `AppStream` directories are
empty-but-valid repository structures. That is enough for the exam tasks that
_create_ repository files (task 2), but if you want a true offline package
mirror — so `dnf install` works without internet — drop a DVD ISO in.

## Step 1 — Place the ISO

```bash
cp /path/to/AlmaLinux-9-DVD.iso iso/
```

Only the first `*.iso` file in `iso/` is used. The ISO must contain `BaseOS/`
and `AppStream/` package trees at its root (DVD-style, not minimal/boot).

## Step 2 — Rebuild the repo server

If the lab is up:

```bash
vagrant destroy -f repo
vagrant up repo
```

If the lab is down:

```bash
vagrant up repo
```

Provisioning copies the entire BaseOS and AppStream contents from the ISO
into the repo server's `/var/www/html/repo/{BaseOS,AppStream}/` and runs
`createrepo_c`. This adds 5 to 15 minutes to the repo's first boot, depending
on disk speed.

## Step 3 — Verify the repo contents

```bash
vagrant ssh control -c "curl -s http://192.168.56.40/repo/BaseOS/Packages/ | head"
```

You should see HTML listing real `.rpm` filenames, not just `repodata/`.

## Notes

- **The ISO is not used by the managed nodes directly.** They mount
  `/mnt/BaseOS` and `/mnt/AppStream` via NFS from the repo server.
- **The default lab works without an ISO.** Managed nodes use AlmaLinux's
  internet mirrors for installs; the in-lab repo is only used by task 2's
  `file://` repository definitions, which only need valid `repodata/` (which
  is created either way).
- **Changing the ISO** requires destroying and recreating only the `repo` VM.
  The other VMs do not need to be touched.

## Related

- [Reference: Networking](../reference/networking.md) — where each share lives.
- [Reference: Topology](../reference/topology.md) — repo server's IP and role.
