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

  defaults = { name, ... }: {
    imports = [ ./base-install.nix ];

    deployment = {
      allowLocalDeployment = true;
    };

    networking.hostName = name;
  };

  nomad-client-1 = _: {
    isUEFI = true;

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/a92690a8-d96c-4305-bfd9-ac4cf7f1c9e6";
      fsType = "ext4";
    };
  };

  thetasinner-testoport = { config, ... }: {
    isUEFI = true;

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
    isUEFI = false;

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/8cd1f3a9-c743-42de-833a-6b9769ebd758";
      fsType = "ext4";
    };
  };

  nomad-client-cdunster = _: {
    isUEFI = true;
  };

  jost-test-os-terone = _: {
    isUEFI = true;
  };

  nomad-client-zippy-hp-2 = _: {
    isUEFI = false;
  };

  nomad-client-zippy-hp-3 = _: {
    isUEFI = false;
  };
}
