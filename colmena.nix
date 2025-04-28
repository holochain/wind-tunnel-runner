inputs:
let
  targetSystem = "x86_64-linux";
in
{
  meta = {
    nixpkgs = import inputs.nixpkgs {
      system = targetSystem;
      config.allowUnfreePredicate = pkg: builtins.elem (inputs.nixpkgs.lib.getName pkg) [ "nomad" ];
    };
  };

  defaults = { name, pkgs, lib, ... }: {
    deployment = {
      allowLocalDeployment = true;
    };

    nix = {
      # Extra lines to be added to /etc/nix/nix.conf
      extraOptions = "experimental-features = nix-command flakes";

      # Add wind-tunnel substituters
      settings = {
        substituters = [ "https://cache.nixos.org" "https://holochain-ci.cachix.org" "https://holochain-wind-tunnel.cachix.org" ];
        trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8=" "holochain-wind-tunnel.cachix.org-1:tnSm+7Y3hDKOc9xLdoVMuInMA2AQ0R/99Ucz5edYGJw=" ];
      };
    };

    system.stateVersion = "24.11";

    networking.hostName = name;

    boot.loader = lib.mkDefault {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    users = {
      mutableUsers = false;
      users.root.hashedPassword = "$y$j9T$LEwPZpyLzb3CKDBEtAi.w1$Uxok0mk4i5AWJ0zbPaqfY6T7Bw5nNYteu69yxqD7Mg/";
    };

    services.tailscale = {
      enable = true;
    };

    services.nomad = {
      enable = true;
      dropPrivileges = false; # Clients require root privileges

      extraPackages = with pkgs; [
        coreutils
        bash
        hexdump
        gnutar
        bzip2
        telegraf
        # Enable unstable and non-default features that Wind Tunnel tests.
        (inputs.holonix.packages.${targetSystem}.holochain.override { cargoExtraArgs = "--features chc,unstable-functions,unstable-countersigning"; })
      ];

      # The Nomad configuration file
      settings = {
        data_dir = "/var/lib/nomad";
        plugin.raw_exec.config.enabled = true;
        acl.enabled = true;
        client = {
          enabled = true;
          servers = [ "nomad-server-01.holochain.org" ];
          artifact.disable_filesystem_isolation = true;
        };
      };
    };
  };

  nomad-client-1 = _: {
    fileSystems."/" = {
      device = "/dev/disk/by-uuid/a92690a8-d96c-4305-bfd9-ac4cf7f1c9e6";
      fsType = "ext4";
    };
  };

  nomad-client-2 = _: {
    fileSystems."/" = {
      device = "/dev/disk/by-uuid/8dabb938-b5e5-4b81-8cd7-65266e25fd37";
      fsType = "ext4";
    };
  };

  thetasinner-testoport = { config, ... }: {
    fileSystems."/" = {
      device = "/dev/disk/by-uuid/727efd61-af0f-4b5d-ab90-8b6fb3221c5b";
      fsType = "ext4";
    };

    console.keyMap = "uk";

    boot.extraModulePackages = with config.boot.kernelPackages; [
      r8125
    ];

    nixpkgs.config.allowBroken = true;
  };

  nomad-client-zippy-hp-1 = _: {
    fileSystems."/" = {
      device = "/dev/disk/by-uuid/8cd1f3a9-c743-42de-833a-6b9769ebd758";
      fsType = "ext4";
    };

    boot.loader = {
      systemd-boot.enable = false;
      grub = {
        enable = true;
        device = "/dev/sda";
        useOSProber = true;
      };
    };
  };
}
