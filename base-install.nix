{ pkgs, ... }: {
  boot = {
    # Kernel modules available for use during the boot process. Must include all modules necessary for mounting the root device
    initrd.availableKernelModules = [
      "ata_piix"
      "ohci_pci"
      "ehci_pci"
      "ahci"
      "sd_mod"
      "sr_mod"
    ];

    # Enable the GRUB bootloader and install it on `sda` drive
    loader.grub = {
      enable = true;
      device = "/dev/sda";
    };
  };

  # Mount the root file system
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Enable the swap partition
  swapDevices = [{ device = "/dev/disk/by-label/swap"; }];

  # Set the system type
  nixpkgs.hostPlatform = "x86_64-linux";

  # Allow proprietary/unfree packages to be installed
  nixpkgs.config.allowUnfree = true;

  nix = {
    # Set nixpkgs version to the latest unstable version
    package = pkgs.nixVersions.latest;

    # Enable the `nix` command and `flakes`
    extraOptions = "experimental-features = nix-command flakes";
  };

  networking = {
    # Set the machine's name
    hostName = "nomad-client";

    # Enable DHCP for all network devices
    useDHCP = true;
  };

  users = {
    # Disable using `passwd` to change user passwords
    mutableUsers = false;

    # Set the password of the root user
    extraUsers.root.password = "init";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11";
}
