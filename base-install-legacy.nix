{ ... }: {
  imports = [ ./base-install.nix ];

  # Enable the GRUB bootloader and install it on `sda` drive
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
}
