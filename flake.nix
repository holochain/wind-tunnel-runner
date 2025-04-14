{
  description = "NixOS configuration for a Nomad client, deployed using Colmena";

  inputs = {
    holonix.url = "github:holochain/holonix?ref=main-0.4";
    nixpkgs.follows = "holonix/nixpkgs";
    flake-parts.follows = "holonix/flake-parts";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "aarch64-darwin" "x86_64-linux" ];

    perSystem = { self', pkgs, system, ... }: {
      formatter = pkgs.nixpkgs-fmt;

      checks.pre-commit = inputs.pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          # Nix
          deadnix.enable = true;
          nixpkgs-fmt.enable = true;
          statix.enable = true;

          # Spell checking
          typos.enable = true;

          # Git
          check-merge-conflicts.enable = true;
          no-commit-to-branch.enable = true;

          # Whitespace
          mixed-line-endings.enable = true;
          trim-trailing-whitespace.enable = true;

          # Markdown
          markdownlint = {
            enable = true;
            settings.configuration = {
              # Don't check line length in code blocks
              line-length.code_blocks = false;
            };
          };
          mdformat.enable = true;

          # Private keys
          detect-private-keys.enable = true;
        };
      };


      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          self'.checks.pre-commit.enabledPackages
          colmena
        ];

        inherit (self'.checks.pre-commit) shellHook;
      };

      packages = {
        default = pkgs.writeShellApplication {
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
            ${pkgs.tailscale}/bin/tailscale up --ssh --advertise-tags=tag:nomad-client --hostname="$node"

            echo "Installation complete"
            echo "It is recommended to reboot for the hostname to take effect."
            while true; do
              read -r -p "Reboot now? (y/n) " yn
              case $yn in
                [yY]*)
                  sudo reboot now
                  break
                  ;;
                [nN]*)
                  break
                  ;;
              esac
            done
          '';
        };

        build = pkgs.writeShellApplication {
          name = "build-script";
          text = "${pkgs.colmena}/bin/colmena build --impure";
        };
      };
    };

    flake.colmena =
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

        defaults = { name, pkgs, ... }: {
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
      };

  };
}
