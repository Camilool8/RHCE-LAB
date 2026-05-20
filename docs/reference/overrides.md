# Override variables

The Vagrantfile picks a provider via this precedence chain:

1. `vagrant up --provider <name>` (CLI flag — wins over everything else)
2. `LAB_PROVIDER=<name>` environment variable
3. `providers.default` in [`config.yaml`](config-yaml.md)
4. Probe for installed hypervisors and pick the first one present (see [Provider matrix](provider-matrix.md))

## `LAB_PROVIDER`

Forces a specific provider for the duration of one `vagrant` invocation (or
the shell session if exported).

Examples:

```bash
LAB_PROVIDER=vmware_desktop vagrant up
LAB_PROVIDER=virtualbox vagrant up
LAB_PROVIDER=libvirt vagrant status
```

Make it permanent for your shell:

```bash
echo 'export LAB_PROVIDER=vmware_desktop' >> ~/.zshrc    # or ~/.bashrc
```

Valid values: `virtualbox`, `libvirt`, `parallels`, `vmware_desktop`.

## `vagrant up --provider <name>`

Vagrant's native CLI flag. Highest precedence. The Vagrantfile scans `ARGV`
explicitly so the flag also drives the lab's provider helpers (memory/CPU,
disk, network):

```bash
vagrant up --provider libvirt
vagrant destroy --provider vmware_desktop -f
```

## `providers.default` in `config.yaml`

The persistent equivalent of `LAB_PROVIDER`. Useful when one host always uses
the same provider:

```yaml
providers:
  default: "vmware_desktop"
```

A blank value (the default) means "use auto-detect".

## What the active provider looks like

Every `vagrant` invocation prints the chosen provider on its first output line:

```
==> RHCE-LAB: host=macos/arm64 provider=parallels box_arch=arm64
```

If that line shows a provider you did not expect, your selection chain has
an earlier rung winning — check `echo $LAB_PROVIDER` and your `config.yaml`.

## Other environment knobs

The Vagrantfile honors only the variables above. It does **not** look at:

- `VAGRANT_DEFAULT_PROVIDER` — Vagrant's own variable. It will work via the
  CLI-flag precedence rung (Vagrant injects it as if `--provider` were
  given) but the lab does not document it because the lab-specific
  `LAB_PROVIDER` is preferred for clarity.
- `LAB_ARCH` — was used in an earlier x86-emulation design that was dropped.
  Setting it has no effect.

## Related

- [Provider matrix](provider-matrix.md).
- [`config.yaml`](config-yaml.md).
