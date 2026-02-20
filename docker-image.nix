{ inputs, nomadSettings, dockerSettings }:
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

  nomadJSON = (linuxPkgs.formats.json { }).generate "nomad.json" (import nomadSettings);

  entrypoint = linuxPkgs.writeShellScript "entrypoint.sh" ''
    exec ${linuxPkgs.nomad_1_11}/bin/nomad agent "-config=${nomadJSON}"
  '';
in
linuxPkgs.dockerTools.buildImage {
  inherit (dockerSettings) name;
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
      nomad_1_11
      inputs.wind-tunnel.packages.x86_64-linux.lp-tool
    ];

    # I hoped this would let us deploy the threefold nodes with `--entrypoint /bin/entrypoint.sh` but it doesn't seem to work.
    # Instead we need to determine the actual path to the script in the nix store i.e. `--entrypoint --entrypoint /nix/store/qp62cxqz121y834q0y4grv0hqszlv6jg-docker-entrypoint.sh`
    # To get the script path manually I ran the docker container locally, entered its shell, and then ran `echo $ENTRYPOINT_SCRIPT`
    postBuild = ''
      mkdir -p $out/bin
      ln -s ${entrypoint} $out/bin/entrypoint.sh
    '';
  };
  config = {
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/holochain/wind-tunnel-runner";
    };
    Env = [
      "ENTRYPOINT_SCRIPT=${entrypoint}"
      "SSL_CERT_FILE=${linuxPkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${linuxPkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    Cmd = [ "/bin/entrypoint.sh" ];
    User = "root";
  };
}
