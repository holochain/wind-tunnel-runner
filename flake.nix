{
  description = "NixOS configuration for a Nomad client, deployed using Colmena";

  inputs = {
    holonix.url = "github:holochain/holonix?ref=main-0.4";
    nixpkgs.follows = "holonix/nixpkgs";
  };

  outputs = { ... }@inputs: {
    colmena = {
      meta = {
        nixpkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
        };
      };

      nomad-client = { ... }: {
        deployment = {
          allowLocalDeployment = true;
        };

        boot.loader.grub.device = "/dev/sda";

        fileSystems."/" = {
          device = "/dev/sda1";
          fsType = "ext4";
        };

        users.users.holochain = {
          isNormalUser = true;
          description = "Holochain Dev Account";
          extraGroups = [ "networkmanager" "wheel" ];
          hashedPassword = "$y$j9T$4uoXeFexvI/s6fylf.UJd.$400SiovRcdEemmxWaFKniWK0a9ZEzwDB2MTn5.gqb70";
        };

        services.tailscale = {
          enable = true;
        };
      };
    };
  };
}
