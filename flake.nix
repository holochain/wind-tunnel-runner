{
  description = "NixOS configuration for a Nomad client, deployed using Colmena";

  inputs = {
    holonix.url = "github:holochain/holonix?ref=main-0.4";
    nixpkgs.follows = "holonix/nixpkgs";
  };

  outputs = { ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; };
    in
    {
      colmena = {
        meta = {
          nixpkgs = pkgs;
        };

        nixos = { name, ... }: {
          deployment = {
            allowLocalDeployment = true;
            targetHost = null; # Only used for local deployment
          };

          system.stateVersion = "24.11";

          networking.hostName = name;

          boot.loader.grub.device = "/dev/sda";

          fileSystems."/" = {
            device = "/dev/sda1";
            fsType = "ext4";
          };

          users = {
            mutableUsers = false;
            users.root.hashedPassword = "$y$j9T$4uoXeFexvI/s6fylf.UJd.$400SiovRcdEemmxWaFKniWK0a9ZEzwDB2MTn5.gqb70";
          };

          services.tailscale = {
            enable = true;
          };
        };
      };

      packages.${system}.default = pkgs.writeShellApplication {
        name = "setup-script";
        text = ''
          cd ${./.}
          ${pkgs.colmena}/bin/colmena apply-local --sudo --impure "$@"
          while ! ${pkgs.procps}/bin/pgrep "tailscaled" > /dev/null; do
            sleep 0.5
          done
          ${pkgs.tailscale}/bin/tailscale up --ssh
        '';
      };
    };
}
