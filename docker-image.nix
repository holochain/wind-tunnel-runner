{ inputs }:
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

  nomadJSON = (linuxPkgs.formats.json { }).generate "nomad.json" (import ./nomad-settings-docker.nix);
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
}
