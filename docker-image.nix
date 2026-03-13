{ inputs
, system ? "x86_64-linux"
, nomadSettings
, dockerSettings
}:
let
  # Use the given system's nixpkgs for the docker image
  linuxPkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfreePredicate = pkg: builtins.elem (linuxPkgs.lib.getName pkg) [ "nomad" ];
  };

  # To update a dockerhub image digest, run the following command:
  # x86_64: nix run nixpkgs#nix-prefetch-docker -- --image-name ubuntu --image-tag 24.04 --os linux --arch amd64
  # aarch64: nix run nixpkgs#nix-prefetch-docker -- --image-name ubuntu --image-tag 24.04 --os linux --arch arm64
  baseImages = {
    "x86_64-linux" = linuxPkgs.dockerTools.pullImage {
      imageName = "ubuntu";
      imageDigest = "sha256:c35e29c9450151419d9448b0fd75374fec4fff364a27f176fb458d472dfc9e54";
      hash = "sha256-0j8xM+mECrBBHv7ZqofiRaeSoOXFBtLYjgnKivQztS0=";
      finalImageName = "ubuntu";
      finalImageTag = "24.04";
    };
    "aarch64-linux" = linuxPkgs.dockerTools.pullImage {
      imageName = "ubuntu";
      imageDigest = "sha256:d1e2e92c075e5ca139d51a140fff46f84315c0fdce203eab2807c7e495eff4f9";
      hash = "sha256-70XdcBIfxzsgvmRDQ5vWOv9QUcReXi3t4baLQnTuOPE=";
      finalImageName = "ubuntu";
      finalImageTag = "24.04";
    };
  };

  nomadJSON = (linuxPkgs.formats.json { }).generate "nomad.json" (import nomadSettings);

  entrypointPath = "/entrypoint.sh";

  entrypointScript = linuxPkgs.writeShellScript (builtins.baseNameOf entrypointPath) ''
    # Wrapper entrypoint that synchronizes the system clock via NTP before starting Nomad.
    # Some runners have very behind system clocks which affects wind-tunnel scenarios.
    ${linuxPkgs.chrony}/bin/chronyd -q 'server pool.ntp.org iburst' 'makestep 1 -1'

    exec ${linuxPkgs.nomad_1_11}/bin/nomad agent "-config=${nomadJSON}"
  '';

  baseRoot = linuxPkgs.buildEnv {
    name = "image-root";
    paths = with linuxPkgs; [
      # additional system packages
      iproute2
      cacert
      iputils
      kmod
      procps
      util-linux

      # wind-tunnel job packages
      hexdump
      influxdb2-cli
      jq
      telegraf
      nomad_1_11
      inputs.wind-tunnel.packages.${system}.lp-tool
    ];

    pathsToLink = [ "/bin" ];
  };

in
linuxPkgs.dockerTools.buildLayeredImage {
  inherit (dockerSettings) name;
  tag = "latest";

  fromImage = baseImages.${system};
  contents = [ baseRoot ];

  extraCommands = ''
    # Ensure entrypointPath is a real file in the root (not a symlink).
    #
    # Threefold requires providing the entrypoint path at deploy-time,
    # and does not seem to work with symlinked entrypoint paths.
    install -Dm755 ${entrypointScript} .${entrypointPath}

    # Ensure certs are real files, not symlinks
    mkdir -p ./etc/ssl/certs
    install -m644 ${linuxPkgs.cacert}/etc/ssl/certs/ca-bundle.crt ./etc/ssl/certs/ca-bundle.crt
    install -m644 ${linuxPkgs.cacert}/etc/ssl/certs/ca-bundle.crt ./etc/ssl/certs/ca-certificates.crt
  '';
  config = {
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/holochain/wind-tunnel-runner";
    };
    Env = [
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "CURL_CA_BUNDLE=/etc/ssl/certs/ca-bundle.crt"
    ];
    Cmd = [ entrypointPath ];
    User = "root";
  };
}
