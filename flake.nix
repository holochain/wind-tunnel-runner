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

        # To build and run the docker container use the following command:
        # nix build .#docker-image && docker load < result && docker run --cgroupns=host --privileged -t --rm wind-tunnel-runner:latest
        docker-image =
          let
            # Use x86_64-linux nixpkgs for docker image regardless of build system
            linuxPkgs = import inputs.nixpkgs {
              system = "x86_64-linux";
              config.allowUnfreePredicate = pkg: builtins.elem (linuxPkgs.lib.getName pkg) [ "nomad" ];
            };

            # To update the dockerhub image, run the following command:
            # nix run nixpkgs#nix-prefetch-docker -- --image-name ubuntu --image-tag 24.04
            # Then copy the output below:
            baseImage = linuxPkgs.dockerTools.pullImage {
              imageName = "ubuntu";
              imageDigest = "sha256:c35e29c9450151419d9448b0fd75374fec4fff364a27f176fb458d472dfc9e54";
              hash = "sha256-0j8xM+mECrBBHv7ZqofiRaeSoOXFBtLYjgnKivQztS0=";
              finalImageName = "ubuntu";
              finalImageTag = "24.04";
            };

            nomadJSON = (linuxPkgs.formats.json { }).generate "nomad.json" (import ./nomad-settings.nix);
          in
          linuxPkgs.dockerTools.buildImage {
            name = "wind-tunnel-runner";
            tag = "latest";

            fromImage = baseImage;
            copyToRoot = linuxPkgs.buildEnv {
              name = "image-root";
              paths = with linuxPkgs; [
                # additional system packages
                iproute2
                cacert

                # wind-tunnel job packages
                hexdump
                influxdb2-cli
                jq
                telegraf
                nomad
                inputs.wind-tunnel.packages.x86_64-linux.lp-tool
              ];
            };
            config = {
              Labels = {
                "org.opencontainers.image.source" = "https://github.com/holochain/wind-tunnel-runner";
              };
              Env = [
                "SSL_CERT_FILE=${linuxPkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "NIX_SSL_CERT_FILE=${linuxPkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              ];
              Cmd = [ "/bin/nomad" "agent" "-config=${nomadJSON}" ];
              User = "root";
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
