# The lab's offline package mirror

The lab is **fully offline after first boot**. There is no ISO drop step,
no DVD attach dance, no per-provider CD-ROM workarounds. The repo server
mirrors the entire upstream AlmaLinux 9 BaseOS and AppStream repositories
during its own `vagrant up` (the *only* moment internet is required), and
every managed node is wired to use that mirror as its only dnf source.

## Why we picked this shape

The previous design copied packages from a user-supplied DVD ISO. That
worked but had three problems:

1. **Manual step.** Someone had to find a 12 GB ISO and remember to drop
   it in `iso/` before `vagrant up`. Without it the lab silently fell
   back to the AlmaLinux online mirrors and tasks 2, 3, 5, and 7 needed
   live internet during practice.
2. **Per-provider attach syntax.** ISOs attach differently on
   VirtualBox / libvirt / Parallels / VMware — the Vagrantfile carried
   four code paths plus a small README.
3. **Always out of date.** Whatever ISO you grabbed last quarter is
   probably behind a couple of security errata by now.

`dnf reposync` solves all three: it pulls *current* metadata, all
packages, comps.xml (so task 3's `RPM Development Tools` group works),
and modular metadata. One internet hit at provisioning time; everything
after that is local.

## What the repo server does

`scripts/repo-server/setup-repos.sh`:

1. `dnf install httpd createrepo_c dnf-plugins-core`.
2. Auto-discover the upstream `baseos` / `appstream` repoids (different
   on RHEL vs AlmaLinux).
3. For each: `dnf reposync --repoid=X --download-metadata
   --downloadcomps --norepopath --delete --gpgcheck -p <dst>`.
4. If `--download-metadata` didn't write a usable `repomd.xml` (older
   dnf, upstream quirk), regenerate with `createrepo_c`.
5. Serve `/var/www/html/repo/` via httpd, open `http` in the `internal`
   firewalld zone.

`scripts/repo-server/setup-nfs.sh` exports the same directories
read-only over NFS to the lab subnet.

The script is **idempotent**. On `vagrant provision` it does a delta
sync. The `REPO_PACKAGE_THRESHOLD` env var (default 500) controls the
heuristic that decides "this mirror is complete enough, just refresh
delta" vs "first time, do the full pull."

## What each managed node does

`scripts/node/setup-node.sh` writes
`/etc/yum.repos.d/lab-offline.repo` pointing at the mirror over HTTP
and **disables every vendor online repo** (`enabled=1` → `enabled=0` on
`almalinux-*.repo`, `redhat-*.repo`, etc.). The result:

- `dnf install foo` resolves against the lab mirror, no internet needed.
- `dnf --enablerepo=baseos install foo` can still reach the vendor
  mirror if a student explicitly opts in.
- Task 2's `BaseOS.repo` / `AppStream.repo` (which the student writes
  with `baseurl: file:///mnt/BaseOS/`) coexists with this — different
  filename, different repo IDs, no collision.

## The `/mnt/{BaseOS,AppStream}` automounts

These are still there. Managed nodes NFS-automount the repo server's
mirror under `/mnt/BaseOS` and `/mnt/AppStream`. The student's task 2
writes a yum repository pointing at those paths via `file://`. So:

- Lab provisioning uses HTTP (`/etc/yum.repos.d/lab-offline.repo`).
- The student's task 2 deliverable uses `file://` over the NFS mount.

Both paths reach the same packages. The dual setup is intentional: it
keeps the student's task 2 work honest (a real `file://` repo against a
real NFS mount) while also guaranteeing dnf works at provision time
*before* the automount is primed.

## Disk and time cost

| Artifact                       | Size on disk     |
| ------------------------------ | ---------------- |
| `/var/www/html/repo/BaseOS`    | ~4 GB            |
| `/var/www/html/repo/AppStream` | ~14 GB           |
| Total                          | ~18 GB           |
| Repo VM RAM during sync        | ~1.5 GB peak     |
| First reposync over 100 Mb/s   | 8 – 20 minutes   |
| Delta sync on re-provision     | seconds to minutes |

The repo VM defaults to 2 GB RAM and inherits the box's default disk
(50 – 128 GB depending on provider — plenty of room).

## When you actually need internet

After the first `vagrant up`:

| Operation                                 | Needs internet? |
| ----------------------------------------- | --------------- |
| `vagrant halt` / `vagrant up` (re-running) | no              |
| Practice tasks 1 – 18                     | no              |
| `dnf install` on a managed node            | no              |
| `ansible-galaxy role install -r requirements.yml` (task 6) | **yes** — pulls from `galaxy.ansible.com` |
| `ansible-galaxy collection install community.general` | **yes** — pulls from Galaxy |
| Pulling the ansible-navigator EE image    | **yes** — pulls from ghcr.io |
| `dnf reposync` (re-mirror)                | **yes** — pulls from AlmaLinux online |

Galaxy and the EE image are not mirrored. If you want full air-gapped
operation including task 6, pre-pull the three tarballs into
`/var/www/html/repo/galaxy/` and rewrite `requirements.yml` to point
there. The collection install + EE image pull would need a private
Galaxy NG / private container registry, which is out of scope for this
lab.

## Related

- [`scripts/repo-server/setup-repos.sh`](../../scripts/repo-server/setup-repos.sh)
- [`scripts/node/setup-node.sh`](../../scripts/node/setup-node.sh)
- [Networking](../reference/networking.md) — HTTP + NFS service map
- [NFS automount](nfs-automount.md) — why we use systemd automount
