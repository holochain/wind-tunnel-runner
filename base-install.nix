{ pkgs, lib, inputs, ... }:
let
  # Set a value with a lower priority than `lib.mkDefault`
  mkBaseDefault = value: lib.mkOverride 1200 value;
in
{
  config = {
    boot = mkBaseDefault {
      # Kernel modules available for use during the boot process. Must include all modules necessary for mounting the root device
      initrd.availableKernelModules = [
        "ata_piix"
        "xhci_pci"
        "ohci_pci"
        "ehci_pci"
        "ahci"
        "nvme"
        "sd_mod"
        "sr_mod"
      ];

      loader = {
        grub = {
          enable = true;
          device = "nodev";
          efiSupport = true;
          efiInstallAsRemovable = true;
        };
        efi.efiSysMountPoint = "/efi-boot";
      };
    };

    # Mount the EFI boot file system
    fileSystems."/efi-boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = [ "nofail" ];
    };

    # Mount the root file system
    fileSystems."/" = mkBaseDefault {
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

      # Add wind-tunnel substituters
      settings = {
        substituters = [ "https://cache.nixos.org" "https://holochain-ci.cachix.org" "https://holochain-wind-tunnel.cachix.org" ];
        trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8=" "holochain-wind-tunnel.cachix.org-1:tnSm+7Y3hDKOc9xLdoVMuInMA2AQ0R/99Ucz5edYGJw=" ];
      };
    };

    networking = {
      # Set the default machine's name
      hostName = mkBaseDefault "nomad-client";

      # Enable DHCP for all network devices
      useDHCP = true;
    };

    users = {
      # Disable using `passwd` to change user passwords
      mutableUsers = false;

      # Set the password of the root user to the one in the password manager
      extraUsers.root.hashedPassword = mkBaseDefault "$y$j9T$LEwPZpyLzb3CKDBEtAi.w1$Uxok0mk4i5AWJ0zbPaqfY6T7Bw5nNYteu69yxqD7Mg/";
    };

    # Run dynamically-linked binaries such as Holochain on NixOS
    programs.nix-ld.enable = true;

    services = {
      getty.helpLine = ''
        ██╗    ██╗██╗███╗   ██╗██████╗     ████████╗██╗   ██╗███╗   ██╗███╗   ██╗███████╗██╗
        ██║    ██║██║████╗  ██║██╔══██╗    ╚══██╔══╝██║   ██║████╗  ██║████╗  ██║██╔════╝██║
        ██║ █╗ ██║██║██╔██╗ ██║██║  ██║       ██║   ██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██║
        ██║███╗██║██║██║╚██╗██║██║  ██║       ██║   ██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██║
        ╚███╔███╔╝██║██║ ╚████║██████╔╝       ██║   ╚██████╔╝██║ ╚████║██║ ╚████║███████╗███████╗
         ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═════╝        ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚══════╝
                          ██████╗ ██╗   ██╗███╗   ██╗███╗   ██╗███████╗██████╗
                          ██╔══██╗██║   ██║████╗  ██║████╗  ██║██╔════╝██╔══██╗
                          ██████╔╝██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██████╔╝
                          ██╔══██╗██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██╔══██╗
                          ██║  ██║╚██████╔╝██║ ╚████║██║ ╚████║███████╗██║  ██║
                          ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝
      '';

      # Enable Tailscale, used for SSH access
      tailscale = {
        enable = true;
        authKeyFile = "/root/secrets/tailscale_key";
        extraUpFlags = [ "--ssh" "--advertise-tags=tag:nomad-client" ];
      };

      # Enable Nomad as a client node
      nomad = {
        enable = true;
        dropPrivileges = false; # Clients require root privileges

        extraPackages = with pkgs; [
          bash
          bzip2
          coreutils
          gnutar
          hexdump
          influxdb2-cli
          jq
          telegraf
          inputs.wind-tunnel.packages.x86_64-linux.lp-tool
        ];

        # Load the Nomad configuration from file
        settings = import ./nomad-settings.nix;
      };
    };

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "24.11";
  };
}
