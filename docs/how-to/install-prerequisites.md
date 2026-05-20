# Install prerequisites for your host OS

Find your host below and run the commands in that section. When the section's
final verification command succeeds, you are done.

## macOS Intel

```bash
brew install --cask virtualbox vagrant
```

Verify:

```bash
VBoxManage --version
vagrant --version
```

## macOS Apple Silicon (M1, M2, M3, M4)

VirtualBox cannot run x86_64 guests on Apple Silicon. Pick one of these
hypervisors:

### Option A — VMware Fusion (free for personal use)

1. Create a Broadcom account at <https://support.broadcom.com>.
2. Download **VMware Fusion 13.x** (free for personal use as of late 2024).
3. Install it, then **launch the app once** so it can prompt for the
   system-level permissions it needs.
4. Install Vagrant and the integration tools:

   ```bash
   brew install --cask vagrant vagrant-vmware-utility
   vagrant plugin install vagrant-vmware-desktop
   ```

5. Start Fusion's host networking. This is a one-time step:

   ```bash
   sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --configure
   sudo "/Applications/VMware Fusion.app/Contents/Library/vmnet-cli" --start
   ```

6. Tell the lab to use this provider:

   ```bash
   export LAB_PROVIDER=vmware_desktop
   ```

   To make this permanent, add the line to `~/.zshrc` (or `~/.bashrc`).

### Option B — Parallels Desktop (paid)

1. Install Parallels Desktop **Pro** (or Business / Enterprise — Standard
   does not expose the API `vagrant-parallels` needs).
2. Install Vagrant and the plugin:

   ```bash
   brew install --cask vagrant
   vagrant plugin install vagrant-parallels
   ```

   `LAB_PROVIDER` is not needed — Parallels is the auto-selected default on
   Apple Silicon.

Verify (either option):

```bash
vagrant --version
LAB_PROVIDER=vmware_desktop vagrant validate    # adjust provider as needed
```

The second command should print `Vagrantfile validated successfully.`

## Linux (x86_64 or arm64)

```bash
# Fedora / AlmaLinux / Rocky
sudo dnf install -y vagrant qemu-kvm libvirt libvirt-devel \
    libguestfs-tools @virtualization
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt "$USER"     # log out and back in afterward
vagrant plugin install vagrant-libvirt
```

```bash
# Debian / Ubuntu
sudo apt update
sudo apt install -y vagrant qemu-system libvirt-daemon-system libvirt-dev \
    ebtables libguestfs-tools dnsmasq-base bridge-utils
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt "$USER"
vagrant plugin install vagrant-libvirt
```

Verify:

```bash
virsh version
vagrant --version
vagrant plugin list | grep libvirt
```

## Windows x86_64

1. Disable **Hyper-V** (Control Panel → Programs → Turn Windows features on or
   off → uncheck *Hyper-V* and *Windows Hypervisor Platform*) **or** accept
   VirtualBox's slower Hyper-V coexistence mode. Reboot after toggling.
2. Install [VirtualBox 7.x](https://www.virtualbox.org/wiki/Downloads).
3. Install [Vagrant 2.4+](https://www.vagrantup.com/downloads).
4. Open a new PowerShell or Command Prompt and verify:

   ```powershell
   VBoxManage.exe --version
   vagrant --version
   ```

## Next step

Return to [Tutorial: first run, Step 2](../tutorial/first-run.md#step-2--get-the-lab-files).
