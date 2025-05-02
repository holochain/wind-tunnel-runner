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
    specialArgs = { inherit inputs; };
  };

  defaults = { name, lib, ... }: {
    imports = [ ./base-install.nix ];

    deployment = {
      allowLocalDeployment = true;
    };

    networking.hostName = name;

    boot.loader = lib.mkDefault {
      grub.enable = false;
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  nomad-client-1 = _: {
    fileSystems."/" = {
      device = "/dev/disk/by-uuid/a92690a8-d96c-4305-bfd9-ac4cf7f1c9e6";
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
