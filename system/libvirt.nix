{ ... }:

{
  # Headless KVM/QEMU + libvirt. `virsh` and QEMU are on PATH via the libvirtd module;
  # no virt-manager / dconf. For a one-off `virt-install` without installing the GUI:
  #   nix shell nixpkgs#virt-manager -c virt-install ...
  # (nix run nixpkgs#virt-manager runs the GUI, not virt-install.)
  #
  # After `nixos-rebuild switch`, log out and back in so the libvirtd group applies.
  # If `virsh net-list` shows default inactive:
  #   sudo virsh net-start default && sudo virsh net-autostart default
  # If /dev/kvm is missing or access fails, enable Intel VT-x in firmware.

  virtualisation.libvirtd.enable = true;

}
