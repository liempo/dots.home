# VM **`tonic`** — Windows 11 IoT Enterprise LTSC

## Purpose

The **`tonic`** guest exists so Liempo can open **tonic.com.au internal domains** from a browser while connected to the corporate VPN. Homestation stays headless; the workload is **Windows 11 IoT Enterprise LTSC** inside KVM/libvirt, not the NixOS host.

Static DHCP and nginx upstream constants live in **`system/libvirt.nix`** (MAC **`52:54:00:72:4f:3c`**, **`192.168.122.50`**) and **`system/nginx.nix`** (Playwright proxy).

---

## Recreating **`tonic.xml`**

Committed **`tonic.xml`** should stay aligned with **`virt-install`** flags and the live domain.

1. Regenerate XML from the same options used for this guest (no ISO in print mode; disk path must exist or use a placeholder path libvirt accepts for comparison):

```bash
nix shell nixpkgs#virt-manager -c virt-install --print-xml \
  --name tonic \
  --memory 8192 \
  --vcpus 4 \
  --disk path=/box/vm/disks/tonic.qcow2,size=80,format=qcow2,bus=virtio \
  --os-variant win11 \
  --boot uefi \
  --network network=default,model=virtio,mac=52:54:00:72:4f:3c \
  --graphics vnc,listen=127.0.0.1
```

2. Merge into **`tonic.xml`** as needed:

   - Keep **`disk`** **`driver`** **`type="qcow2"`** if you want an explicit format.
   - Keep explicit VNC listen: **`graphics`** with **`listen="127.0.0.1"`** and **`<listen type="address" address="127.0.0.1"/>`**.
   - Omit **`uuid`** in git unless you intentionally pin the domain UUID.
   - **`emulator`** should match the host; on NixOS this is typically **`/run/current-system/sw/bin/qemu-system-x86_64`**. If **`virsh define`** rejects the path, copy **`<emulator>…</emulator>`** from **`sudo virsh dumpxml tonic`** or another working guest.

3. Compare to the running definition:

```bash
sudo virsh dumpxml tonic | diff -u tonic.xml - | less
```

4. Validate and apply on **homestation** (paths assume this repo at **`~/.dots`**):

```bash
sudo virsh define --validate "$HOME/.dots/vm/tonic.xml"
```

New domain:

```bash
sudo virsh define "$HOME/.dots/vm/tonic.xml"
```

Replace an existing **`tonic`** persistent XML while keeping UEFI NVRAM:

```bash
virsh shutdown tonic
sudo virsh dumpxml tonic > "/tmp/tonic-backup-$(date +%F).xml"
sudo virsh undefine tonic --keep-nvram
sudo virsh define "$HOME/.dots/vm/tonic.xml"
virsh start tonic
```
