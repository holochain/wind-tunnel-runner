{
  description = "NixOS configuration for a Nomad client, deployed using Colmena";

  inputs = {
    holonix.url = "github:holochain/holonix?ref=main-0.5";
    nixpkgs.follows = "holonix/nixpkgs";
    flake-parts.follows = "holonix/flake-parts";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wind-tunnel.url = "github:holochain/wind-tunnel/main";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "aarch64-darwin" "x86_64-linux" ];

    perSystem = { self', pkgs, system, ... }: {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [ "nomad" ];
      };

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
          nomad
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
            ${pkgs.coreutils-full}/bin/mkdir -p /root/secrets
            ${pkgs.curl}/bin/curl -L https://github.com/holochain/wind-tunnel-runner/releases/latest/download/tailscale_key -o /root/secrets/tailscale_key
            ${pkgs.colmena}/bin/colmena apply-local --impure --node="$node"
            while ! ${pkgs.procps}/bin/pgrep "tailscaled" > /dev/null; do
              sleep 0.5
            done
            ${pkgs.tailscale}/bin/tailscale up --ssh --advertise-tags=tag:nomad-client --accept-risk=lose-ssh --hostname="$node"

            echo "Installation complete"
            echo "It is recommended to reboot for the hostname to take effect."
            while true; do
              read -r -n 1 -p 'Reboot now? [y/n] ' yn
              echo ""
              case $yn in
                [yY]*)
                  reboot now
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
          text = "${pkgs.colmena}/bin/colmena build";
        };

        apply = pkgs.writeShellApplication {
          name = "apply-script";
          text = "${pkgs.colmena}/bin/colmena apply --reboot";
        };

        installer-iso = inputs.self.nixosConfigurations.installer.config.system.build.isoImage;

        docker-image =
          let
            nomadJSON = (pkgs.formats.json { }).generate "nomad.json" (import ./nomad-settings.nix);
          in
          pkgs.dockerTools.buildImage {
            name = "wind-tunnel-runner";
            tag = "latest";
            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              pathsToLink = [ "/bin" ];
              paths = [
                pkgs.coreutils
                pkgs.iproute2
                pkgs.iptables
                pkgs.nomad
              ];
            };
            config = {
              Cmd = [ "${pkgs.nomad}/bin/nomad" "agent" "-config=${nomadJSON}" ];
            };
          };
      };
    };

    flake.colmena = import ./colmena.nix inputs;

    flake.nixosConfigurations.installer = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./installer.nix ];
      specialArgs = { inherit inputs; };
    };
  };
}
