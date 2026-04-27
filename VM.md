# VMs on homestation (libvirt / KVM)

Homestation runs **headless** NixOS with **libvirt** enabled (`system/libvirt.nix`, `virtualisation.libvirtd` in the flake). This guide assumes:

- **`/dev/kvm` exists** (Intel VT-x enabled in firmware).
- Your user is in the **`libvirtd`** group (log out/in after `nixos-rebuild switch`).
- ISOs and disk images live on **`/box`** (large disk). Guests reach **`/box` over the network via Samba** (`box` share — see `system/services.nix` and §5).

Use **`virsh`**, **`qemu-img`**, and **`virt-install`** (via `nix shell` below). Default VM disks are usually under `/var/lib/libvirt/images/` unless you override `--disk path=...`.

---

## 1. One-time host prep

### Libvirt NAT network

```bash
virsh net-list --all
```

If **`default`** is inactive:

```bash
sudo virsh net-start default
sudo virsh net-autostart default
```

### `virt-install` without installing a GUI

`virt-install` is in the same **`virt-manager`** nixpkgs package as the GUI, but **`nix run nixpkgs#virt-manager`** only starts **virt-manager** (GTK). Arguments after `--` go to that program, not to `virt-install`.

Use a **shell** so the correct binary runs:

```bash
nix shell nixpkgs#virt-manager -c virt-install --help
```

Match **`nixpkgs`** to your flake input if you care about reproducibility; `nixpkgs#virt-manager` is fine for ad hoc use.

---

## 2. Put ISOs on the host

Example layout:

```text
/box/vm/ios/ubuntu-24.04.iso
/box/vm/ios/Win11_24H2.iso
/box/vm/disks/          # optional: store qcow2 here instead of /var/lib/libvirt/images
```

Ensure the libvirt/qemu user can read ISO paths (permissions on `/box`; you already use this mount for other services).

---

## 3. Ubuntu guest (from ISO)

### Console-friendly install (serial)

Many Ubuntu server ISOs work with a serial console for fully headless install:

```bash
nix shell nixpkgs#virt-manager -c virt-install \
  --name ubuntu-vm \
  --memory 4096 \
  --vcpus 2 \
  --disk path=/box/vm/disks/ubuntu-vm.qcow2,size=40,format=qcow2,bus=virtio \
  --location /box/vm/ios/ubuntu-24.04.iso \
  --os-variant ubuntu24.04 \
  --network network=default,model=virtio \
  --graphics none \
  --console pty,target_type=serial \
  --extra-args 'console=ttyS0,115200n8'
```

**Notes:**

- `--location` + kernel/extra-args behavior varies by ISO; if the installer does not bind to the serial console, use **VNC for the install only** (next section), then destroy/recreate or change XML later.
- Adjust **`ubuntu24.04`** with `osinfo-query os` if needed.

### Install with VNC (then go headless)

Bind VNC to localhost and forward over SSH:

```bash
nix shell nixpkgs#virt-manager -c virt-install \
  --name ubuntu-desktop-temp \
  --memory 4096 \
  --vcpus 2 \
  --disk path=/box/vm/disks/ubuntu.qcow2,size=64,format=qcow2,bus=virtio \
  --cdrom /box/vm/ios/ubuntu-24.04.iso \
  --os-variant ubuntu24.04 \
  --network network=default,model=virtio \
  --graphics vnc,listen=127.0.0.1 \
  --boot uefi
```

From your laptop:

```bash
ssh -L 5900:127.0.0.1:5900 liempo@homestation
```

Open a VNC client to `127.0.0.1:5900` (port may differ; `virsh domdisplay ubuntu-desktop-temp` shows it).

### After install

```bash
virsh list --all
virsh start ubuntu-vm
virsh console ubuntu-vm          # if serial/getty configured in guest
```

---

## 4. Windows 11 guest (from ISO)

### Windows 11 IoT Enterprise LTSC — TPM optional (Microsoft spec)

For **Windows 11 IoT Enterprise LTSC**, Microsoft’s **optional minimum** hardware tier lists **TPM 2.0 as optional** (UEFI may be replaced by BIOS in that tier; the **preferred** tier still lists TPM 2.0 and UEFI). See [Minimum System Requirements for Windows IoT Enterprise](https://learn.microsoft.com/en-us/windows/iot/iot-enterprise/hardware/system_requirements) (table: TPM — optional minimum column applies to IoT Enterprise LTSC).

So for an **LTSC** install you can **omit `--tpm`** in `virt-install` and avoid **swtpm** / libvirt TPM wiring entirely, as long as you accept the optional-tier tradeoffs (some features and policies assume a TPM).

Example (no `--tpm`; match `--cdrom` to your real path, e.g. `/box/vm/ios/...`):

```bash
nix shell nixpkgs#virt-manager -c virt-install \
  --name win11 \
  --memory 8192 \
  --vcpus 4 \
  --disk path=/box/vm/disks/win11.qcow2,size=80,format=qcow2,bus=virtio \
  --cdrom /box/vm/ios/windows_11_ltsc.iso \
  --os-variant win11 \
  --boot uefi \
  --network network=default,model=virtio \
  --graphics vnc,listen=127.0.0.1
```

**Shell tip:** do not put a space after a line-ending `\`; otherwise the next line is not continued.

### Consumer Windows 11 (Home / Pro retail ISO)

Those SKUs follow the stricter consumer bar (**TPM 2.0** is part of the usual install story). For a VM, add emulated TPM when your host supports it:

```bash
  --tpm backend.type=emulator,backend.version=2.0 \
```

That requires **swtpm** integrated with libvirt (e.g. `virtualisation.libvirtd.qemu.swtpm.enable` on NixOS). If libvirt answers `TPM version '2.0' is not supported`, enable that stack or use an ISO/deployment path that does not require TPM.

**VirtIO drivers (disk/network):** The installer may not see **virtio** disks until drivers load. Typical approaches:

1. Add a **second CD** with the [VirtIO guest tools ISO](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) (`--disk device=cdrom` or attach after first boot in `virsh edit`), **Load driver** during setup, or  
2. Use **SATA/SCSI** for the install disk (`bus=sata`) and switch to virtio later (more steps).

**Licensing / activation:** Your responsibility; this doc only covers mechanics.

---

## 5. Accessing `/box` from guests (Samba) — recommended

Homestation serves the host directory **`/box`** over the network as the **`box`** share for user **`liempo`** (see `system/services.nix`). **Linux and Windows guests** should use this; do not rely on libvirt filesystem passthrough for `/box`.

**On the host:** create subdirectories under `/box` as usual (`mkdir`, ownership for your user). Samba exposes the whole tree under `box`.

**From a guest on `network=default`**, use the **libvirt NAT gateway** on the host (usually **`192.168.122.1`** — confirm with `ip -br a` on homestation). If the guest can route to homestation by **LAN or Tailscale hostname**, that works too.

**Linux — mount entire `/box`:**

```bash
sudo mkdir -p /mnt/box
sudo mount -t cifs //192.168.122.1/box /mnt/box -o username=liempo,uid=$(id -u)
```

**Linux — mount only a subfolder** (e.g. `example` under `/box`; `prefixpath` is relative to `/box` on the host):

```bash
sudo mkdir -p /mnt/example
sudo mount -t cifs //192.168.122.1/box /mnt/example -o username=liempo,uid=$(id -u),prefixpath=example
```

**Windows:** In File Explorer use **`\\192.168.122.1\box`** (or map a network drive to that UNC). Open subfolders as needed (e.g. `tonic` under the share if you use `\\192.168.122.1\box\tonic`).

Samba is already allowed in the homestation firewall config for this use case; NAT guests normally reach the host on `virbr0`.

---

## 6. ISO / CD swap after install

```bash
virsh change-media win11 sda /box/vm/ios/virtio-win.iso --insert
```

Device name (`sda`, `hdc`, …) depends on your VM XML — use `virsh domblklist win11`.

---

## 7. Useful commands

| Action | Command |
|--------|---------|
| List VMs | `virsh list --all` |
| Start / shutdown | `virsh start NAME` / `virsh shutdown NAME` |
| Force off | `virsh destroy NAME` |
| Delete VM + disk | `virsh undefine NAME --remove-all-storage` (check carefully) |
| Console | `virsh console NAME` (needs serial/getty in guest) |
| VNC display | `virsh domdisplay NAME` |
| Autostart at boot | `virsh autostart NAME` |
| Edit domain XML | `sudo env EDITOR="$(command -v nvim)" virsh edit NAME` (see §8 if `vi` missing) |

---

## 8. Troubleshooting

- **`/dev/kvm` missing** → firmware VT-x / VMX (see kernel log: `VMX not enabled (by BIOS)`).
- **No network in guest** → `default` net active; virtio driver in guest for NIC.
- **`virt-install` not found** → use `nix shell nixpkgs#virt-manager -c virt-install ...`.

For XML editing: **`virsh edit NAME`** uses **`$EDITOR`** (then **`$VISUAL`**, then **`vi`**).

**NixOS / `sudo`:** `EDITOR=nvim sudo virsh edit …` often fails with **`Cannot find 'vi' in path`** because **`sudo` resets the environment**, so `virsh` never sees `EDITOR` and falls back to **`vi`** (not installed on many NixOS systems). Use one of:

```bash
sudo env EDITOR="$(command -v nvim)" virsh edit tonic
# or, if your virsh supports it:
sudo virsh edit --editor "$(command -v nvim)" tonic
# or preserve your user env (requires sudoers `SETENV` / permissive env_keep if restricted):
sudo -E virsh edit tonic   # after: export EDITOR="$(command -v nvim)"
```
