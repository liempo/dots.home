# VM **`tonic`** — Windows 11 IoT Enterprise LTSC

## Purpose

The **`tonic`** guest exists so Liempo can open **tonic.com.au internal domains** from a browser while connected to the corporate VPN. Homestation stays headless; the workload is **Windows 11 IoT Enterprise LTSC** inside KVM/libvirt, not the NixOS host.

---

## How this ties to homestation

- **Libvirt / KVM** is enabled on **homestation** (`system/libvirt.nix`, flake).
- User **`liempo`** is in **`libvirtd`** (log out and back in after `nixos-rebuild switch` if group membership changed).
- **`default`** NAT network uses a **static DHCP lease** for **`tonic`** so its IP never moves (needed for host-side proxy in `system/libvirt.nix`):

  | Setting | Value |
  | ------- | ----- |
  | Domain name | **`tonic`** |
  | NIC MAC | **`52:54:00:72:4f:3c`** (must match the guest’s libvirt NIC) |
  | IPv4 | **`192.168.122.50`** |
  | Libvirt gateway | **`192.168.122.1`** (`virbr0`) |

  After changing MAC or IP in **`system/libvirt.nix`**, run **`update`** (or `nixos-rebuild switch`) so **`/var/lib/libvirt/qemu/networks/default.xml`** is regenerated; then restart/redefine the **`default`** net if libvirt already created it (`sudo virsh net-destroy default && sudo virsh net-start default` — only when no guests depend on it, or reboot).

- ISOs and the **`tonic`** disk image live under **`/box`** (see **`mkdir`** / ownership for **`liempo`**). Guests reach **`/box`** over the network via Samba **`\\192.168.122.1\box`** if needed.

---

## One-time host prep

### Libvirt **`default`** network

```bash
virsh net-list --all
```

If **`default`** is inactive:

```bash
sudo virsh net-start default
sudo virsh net-autostart default
```

### **`virt-install`**

`virt-install` ships in the **`virt-manager`** nixpkgs output; run it via a shell:

```bash
nix shell nixpkgs#virt-manager -c virt-install --help
```

---

## Create the **`tonic`** VM (Windows 11 IoT Enterprise LTSC)

**LTSC IoT** allows the **optional minimum** hardware profile where **TPM 2.0 is optional**, so this install **omits `--tpm`** and avoids swtpm wiring. See Microsoft’s [Windows IoT Enterprise system requirements](https://learn.microsoft.com/en-us/windows/iot/iot-enterprise/hardware/system_requirements).

1. Put the **Windows 11 IoT Enterprise LTSC** ISO on the host, e.g. **`/box/vm/ios/`** (exact filename is up to you).

2. Ensure **`/box/vm/disks`** exists and is readable by libvirt/qemu.

3. Run **`virt-install`** with **`--name tonic`**, the **fixed MAC** above (so the NixOS DHCP reservation applies), **UEFI**, **no TPM**, **VNC on loopback** for the interactive installer:

```bash
nix shell nixpkgs#virt-manager -c virt-install \
  --name tonic \
  --memory 8192 \
  --vcpus 4 \
  --disk path=/box/vm/disks/tonic.qcow2,size=80,format=qcow2,bus=virtio \
  --cdrom /box/vm/ios/YOUR_LTSC_ISO.iso \
  --os-variant win11 \
  --boot uefi \
  --network network=default,model=virtio,mac=52:54:00:72:4f:3c \
  --graphics vnc,listen=127.0.0.1
```

Replace **`YOUR_LTSC_ISO.iso`** with the real path.

**VirtIO disk:** If Windows Setup does not see the disk, attach the [VirtIO driver ISO](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) as a second CD (`virsh attach-disk` / **`virsh edit tonic`**) and use **Load driver** during setup, or temporarily install to **SATA** (`bus=sata`) and switch to virtio later.

**Shell tip:** no space after a line-ending **`\`**.

### Installer access over SSH

From another machine:

```bash
ssh -L 5900:127.0.0.1:5900 liempo@homestation
```

Use a VNC client on **`127.0.0.1:5900`** (display port may differ — **`virsh domdisplay tonic`** on homestation).

---

## Guest setup (VPN + tonic.com.au)

1. Finish Windows setup, updates, and **VirtIO** drivers if not done during install.
2. Install the **corporate VPN client** required for tonic.com.au internal access.
3. Connect the VPN from inside **`tonic`**.
4. Use a browser in the guest for **internal** **`*.tonic.com.au`** (and related tooling). Split-tunnel vs full-tunnel behavior follows whatever IT configures on the VPN profile.

Licensing / activation is outside this repo.

---

## Optional: **`box`** share from **`tonic`**

Homestation exposes **`/box`** as SMB share **`box`** for **`liempo`**. From **`tonic`**:

- **`\\192.168.122.1\box`** (e.g. **`\\192.168.122.1\box\tonic`** for project paths).

---

## Day-to-day commands (**`tonic`**)

| Action | Command |
|--------|---------|
| List guests | `virsh list --all` |
| Start / ACPI shutdown | `virsh start tonic` / `virsh shutdown tonic` |
| Force off | `virsh destroy tonic` |
| VNC URL | `virsh domdisplay tonic` |
| Autostart at boot | `virsh autostart tonic` |
| Edit XML | `sudo env EDITOR="$(command -v nvim)" virsh edit tonic` |

---

## Troubleshooting

- **`/dev/kvm` missing** → enable VT-x/AMD-V in firmware.
- **Wrong IP on **`tonic`** → NIC MAC must be **`52:54:00:72:4f:3c`** or **`system/libvirt.nix`** must be updated to match **`sudo virsh dumpxml tonic`** / **`nixos-rebuild switch`**.
- **`virt-install` not found** → use **`nix shell nixpkgs#virt-manager -c virt-install …`**.
- **`vi` missing on `sudo virsh edit`** → use **`sudo env EDITOR="$(command -v nvim)" virsh edit tonic`** or **`sudo virsh edit --editor "$(command -v nvim)" tonic`**.
