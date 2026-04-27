# VMs on homestation (libvirt / KVM)

Homestation runs **headless** NixOS with **libvirt** enabled (`system/libvirt.nix`, `virtualisation.libvirtd` in the flake). This guide assumes:

- **`/dev/kvm` exists** (Intel VT-x enabled in firmware).
- Your user is in the **`libvirtd`** group (log out/in after `nixos-rebuild switch`).
- ISOs and disk images live on **`/box`** (large disk; optional Samba share `box` — see `system/services.nix`).

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

## 5. “Mounting stuff” (host ↔ guest)

### Mount a host folder such as `/box/example`

On the **host**, create the directory once (if it does not exist) and make sure QEMU can traverse the path (libvirt runs guests as **`qemu-libvirtd`**):

```bash
sudo mkdir -p /box/example
# Every directory from / down to /box/example needs the execute bit for "others"
# (or use ACLs) so qemu can reach the folder. Example:
sudo chmod o+rx /box /box/example
# optional: put files there as liempo
sudo chown liempo:users /box/example
```

Below, **`/box/example`** is the host path; pick one method (virtiofs is usually best on **Linux** guests; **Samba** works for **Windows** and Linux without changing VM XML).

---

### A. Samba share of `/box` (already on homestation)

The host shares **`/box`** as **`box`** for user **`liempo`** (see `system/services.nix`). Anything under `/box`—including **`/box/example`**—appears under that share.

From a guest on **`network=default`**, reach the host by **libvirt’s gateway IP** (often **`192.168.122.1`** on `virbr0` — confirm with `ip -br a` on homestation).

**Linux guest — mount whole share, then use the subfolder:**

```bash
sudo mkdir -p /mnt/box
sudo mount -t cifs //192.168.122.1/box /mnt/box -o username=liempo,uid=$(id -u)
ls /mnt/box/example
```

**Linux guest — mount only the `example` subfolder at `/mnt/example`** (same share `box`; `prefixpath` is relative to `/box` on the host):

```bash
sudo mkdir -p /mnt/example
sudo mount -t cifs //192.168.122.1/box /mnt/example -o username=liempo,uid=$(id -u),prefixpath=example
```

**Windows guest:** Map drive `\\<host-ip>\box` and open the **`example`** folder, or use `\\<host-ip>\box\example` if your client allows a deeper UNC path (behavior varies; mapping `\\host\box` and navigating to `example` is the most compatible).

Use the **actual** virbr address for your machine, or homestation’s **Tailscale / LAN hostname** if the guest reaches it that way.

Firewall: Samba is already opened in your config; NAT guests can normally reach the host on `virbr0`.

---

### B. Virtiofs — passthrough `/box/example` (Linux guest)

**virtiofs** shares one host directory into the guest as a fast POSIX filesystem. Good for **`/box/example`** when the guest is Linux and you control the VM definition.

1. Guest kernel must support **virtiofs** (many Ubuntu images do).
2. **`virt-install`**: add a filesystem line (tag is arbitrary; used inside the guest):

```bash
nix shell nixpkgs#virt-manager -c virt-install \
  ... \
  --filesystem /box/example,boxexample,type=mount,driver.type=virtiofs
```

3. **Inside the Linux guest** after boot:

```bash
sudo mkdir -p /mnt/box-example
sudo mount -t virtiofs boxexample /mnt/box-example
```

4. **Optional — fstab** (guest):

```fstab
boxexample  /mnt/box-example  virtiofs  defaults  0  0
```

**Existing VM:** `virsh edit <name>` and add a `<devices>` entry (adjust for your libvirt/QEMU version if the parser complains):

```xml
<memoryBacking>
  <source type="memfd"/>
  <access mode="shared"/>
</memoryBacking>
...
<filesystem type="mount" accessmode="passthrough">
  <driver type="virtiofs"/>
  <source dir="/box/example"/>
  <target dir="boxexample"/>
</filesystem>
```

Then on the guest: `sudo mount -t virtiofs boxexample /mnt/box-example`. Cold-plug changes usually require **shut down** the VM, edit XML, start again.

**Security:** `passthrough` uses host UID/GID semantics; only share directories you trust.

---

### C. Plan 9 / 9p — `/box/example` (Linux guest)

Works on more kernels than virtiofs; a bit slower. At install time:

```text
--filesystem /box/example,box9p,type=mount,accessmode=mapped
```

**Inside the guest:**

```bash
sudo mkdir -p /mnt/box-example
sudo mount -t 9p -o trans=virtio,version=9p2000.L,msize=65536 box9p /mnt/box-example
```

For an **existing** VM, add a `<filesystem type='mount'>` block with `<source dir='/box/example'/>` and `<target dir='box9p'/>` via `virsh edit`, then mount as above.

---

### D. Extra virtual disk (block device)

Create a qcow2 and attach:

```bash
qemu-img create -f qcow2 /box/vm/disks/win11-data.qcow2 100G
virsh attach-disk win11 /box/vm/disks/win11-data.qcow2 vdb --cache none
```

Inside the guest, partition/format the new disk. Use **`virsh detach-disk`** before moving files if you need a clean detach.

---

### E. ISO / CD swap after install

```bash
virsh change-media win11 sda /box/vm/ios/virtio-win.iso --insert
```

Device name (`sda`, `hdc`, …) depends on your VM XML — use `virsh domblklist win11`.

---

## 6. Useful commands

| Action | Command |
|--------|---------|
| List VMs | `virsh list --all` |
| Start / shutdown | `virsh start NAME` / `virsh shutdown NAME` |
| Force off | `virsh destroy NAME` |
| Delete VM + disk | `virsh undefine NAME --remove-all-storage` (check carefully) |
| Console | `virsh console NAME` (needs serial/getty in guest) |
| VNC display | `virsh domdisplay NAME` |
| Autostart at boot | `virsh autostart NAME` |

---

## 7. Troubleshooting

- **`/dev/kvm` missing** → firmware VT-x / VMX (see kernel log: `VMX not enabled (by BIOS)`).
- **No network in guest** → `default` net active; virtio driver in guest for NIC.
- **`virt-install` not found** → use `nix shell nixpkgs#virt-manager -c virt-install ...`.
- **Permission on ISO** → `ls -l` on host path; libvirt runs qemu as `qemu-libvirtd` — directories need traverse (`x`) for others or adjust ACLs.

For XML editing: `virsh edit NAME` (uses `$EDITOR`).
