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

        defaults = { name, ... }: {
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
          if [[ -v 1 ]]; then
              node="$1"
          else
              read -r -p "Enter node name: " node
          fi

          cd ${./.}
          ${pkgs.colmena}/bin/colmena apply-local --sudo --impure --node="$node"
          while ! ${pkgs.procps}/bin/pgrep "tailscaled" > /dev/null; do
            sleep 0.5
          done
          ${pkgs.tailscale}/bin/tailscale up --ssh --hostname="$node"
        '';
      };
    };
}
