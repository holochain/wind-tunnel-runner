{ ... }: {
  imports = [ ./base-install.nix ];

  # Enable the systemd-boot bootloader with UEFI support
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
}
