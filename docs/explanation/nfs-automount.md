# NFS automount

The managed nodes mount the repo server's BaseOS and AppStream shares using
**systemd automount**, not the traditional `fstab + mount -a` pattern.

## What the fstab entries look like

`scripts/node/setup-node.sh` writes these lines to each managed node's
`/etc/fstab`:

```
192.168.56.40:/var/www/html/repo/BaseOS    /mnt/BaseOS    nfs \
    x-systemd.automount,x-systemd.idle-timeout=600,\
    x-systemd.device-timeout=10,_netdev,nofail,ro,vers=4.2,noatime 0 0

192.168.56.40:/var/www/html/repo/AppStream /mnt/AppStream nfs \
    x-systemd.automount,x-systemd.idle-timeout=600,\
    x-systemd.device-timeout=10,_netdev,nofail,ro,vers=4.2,noatime 0 0
```

## What this gives you

| Option | Effect |
|---|---|
| `x-systemd.automount` | systemd creates `mnt-BaseOS.automount` and `mnt-BaseOS.mount` units. Nothing is actually mounted at boot. |
| `x-systemd.idle-timeout=600` | After 10 minutes idle, the mount drops. |
| `x-systemd.device-timeout=10` | If the NFS server is unreachable, retry for at most 10 s before giving up *on this attempt*. The automount will re-try on the next access. |
| `_netdev` | Wait for `network-online.target` before attempting the mount. |
| `nofail` | If the mount cannot complete, do not fail boot. |
| `ro` | Read-only. The shares are repo content. |
| `vers=4.2` | NFSv4.2 only. v4 needs only port 2049 (no rpc-bind shuffle for the client). |
| `noatime` | No atime updates. Cheaper and unnecessary for repos. |

## Why not `fstab + bg + retry=N`

The traditional pattern is:

```
... nfs ro,_netdev,bg,retry=N 0 0
```

With `bg`, the foreground mount retries for `retry` minutes (default
**2 minutes**) before forking to the background. With two shares per node
and five nodes, a first-boot repo-server outage costs **20 minutes of pure
mount-retry burn** across the lab — for shares the student may not touch
during the session. We hit exactly this during early testing.

`systemd.automount` avoids the boot-time mount attempt entirely: no
retry windows, no waiting. The first access of `/mnt/BaseOS/repodata/`
triggers a fresh mount with a 10-second timeout.

## Inspecting the automount

On a managed node before first access:

```bash
mount | grep '/mnt/BaseOS'
# systemd-1 on /mnt/BaseOS type autofs (rw,relatime,fd=56,...)
```

After triggering a first access:

```bash
ls /mnt/BaseOS/repodata/repomd.xml      # triggers
mount | grep '/mnt/BaseOS'
# 192.168.56.40:/var/www/html/repo/BaseOS on /mnt/BaseOS type nfs4 (...)
```

Wait 10 minutes idle and `mount` will show the autofs entry again, with the
nfs4 line gone.

## Why not `autofs` (the package)

`autofs` is the right tool for **parameterized**, dynamic mounts — for
example a per-user home directory mount under `/home/USER`. For a small,
fixed set of known mount points (our two), systemd's built-in `automount` is
simpler:

- No extra package to install.
- No `/etc/auto.master` and `/etc/auto.misc` to maintain.
- Configuration lives in one place (the fstab line).

The RHEL 9 Managing File Systems documentation specifically recommends
systemd automount for this case.

## Related

- [Reference: networking](../reference/networking.md) — full NFS export map.
- [Troubleshoot the lab network](../how-to/troubleshoot-network.md) — when
  the automount cannot reach the server.
