{ inputs, config, pkgs, lib, modulesPath, ... }:
let
  legacySystem = lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./base-install.nix
      { isUEFI = false; }
    ];
    specialArgs = { inherit inputs; };
  };
  uefiSystem = lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./base-install.nix
      { isUEFI = true; }
    ];
    specialArgs = { inherit inputs; };
  };
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  isoImage = {
    isoBaseName = lib.mkForce "wind-tunnel-runner-auto-installer";
    volumeID = "wind-tunnel-runner-installer";
  };

  nix = {
    # Set nixpkgs version to the latest unstable version
    package = pkgs.nixVersions.latest;

    # Enable the `nix` command and `flakes`
    extraOptions = "experimental-features = nix-command flakes";
  };

  services.getty.helpLine = ''
                       ██╗    ██╗██╗███╗   ██╗██████╗     ████████╗██╗   ██╗███╗   ██╗███╗   ██╗███████╗██╗
                       ██║    ██║██║████╗  ██║██╔══██╗    ╚══██╔══╝██║   ██║████╗  ██║████╗  ██║██╔════╝██║
                       ██║ █╗ ██║██║██╔██╗ ██║██║  ██║       ██║   ██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██║
                       ██║███╗██║██║██║╚██╗██║██║  ██║       ██║   ██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██║
                       ╚███╔███╔╝██║██║ ╚████║██████╔╝       ██║   ╚██████╔╝██║ ╚████║██║ ╚████║███████╗███████╗
                        ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═════╝        ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚══════╝

    ██████╗ ██╗   ██╗███╗   ██╗███╗   ██╗███████╗██████╗     ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗
    ██╔══██╗██║   ██║████╗  ██║████╗  ██║██╔════╝██╔══██╗    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗
    ██████╔╝██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██████╔╝    ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝
    ██╔══██╗██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██╔══██╗    ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗
    ██║  ██║╚██████╔╝██║ ╚████║██║ ╚████║███████╗██║  ██║    ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
    ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝    ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝

    Automatically erasing disk and installing Wind Tunnel Runner.
  '';

  services.journald.console = "/dev/tty1";

  systemd.services.install = {
    description = "Bootstrap Wind Tunnel Runner NixOS installation";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "polkit.service" ];
    path = [ "/run/current-system/sw/" ];
    script = with pkgs; ''
      set -euxo pipefail

      wait_for() {
        for _ in $(seq 10); do
          if $@; then
            return
          fi
          sleep 1
        done
        exit 1
      }

      [ -b /dev/sda ] && dev=/dev/sda
      [ -b /dev/vda ] && dev=/dev/vda
      [ -d /sys/firmware/efi ] && [ -b /dev/nvme0n1 ] && dev=/dev/nvme0n1

      if [ -z ''${dev+x} ]; then
        echo "Cannot find drive to install on, aborting"
        exit 1
      else
        echo "Erasing $dev and installing Wind Tunnel Runner NixOS"
      fi

      ${parted}/bin/parted -s "$dev" -- mklabel gpt \
        mkpart primary 0% 2MiB \
        name 1 bios \
        set 1 bios_grub on \
        mkpart ESP fat32 2MiB 512MiB \
        name 2 boot \
        set 2 esp on \
        mkpart root ext4 512MiB -8GiB \
        name 3 nixos \
        mkpart swap linux-swap -8GiB 100% \
        name 4 swap

      ${coreutils-full}/bin/sync

      wait_for [ -b /dev/disk/by-partlabel/nixos ]
      ${e2fsprogs}/bin/mkfs.ext4 -L nixos /dev/disk/by-partlabel/nixos

      wait_for [ -b /dev/disk/by-partlabel/swap ]
      ${util-linux}/bin/mkswap -L swap /dev/disk/by-partlabel/swap

      wait_for [ -b /dev/disk/by-partlabel/boot ]
      ${dosfstools}/bin/mkfs.fat -F 32 -n boot /dev/disk/by-partlabel/boot

      ${coreutils-full}/bin/sync

      wait_for [ -b /dev/disk/by-label/nixos ]
      mount /dev/disk/by-label/nixos /mnt

      wait_for [ -b /dev/disk/by-label/boot ]
      ${coreutils-full}/bin/mkdir -p /mnt/efi-boot
      mount -o umask=077 /dev/disk/by-label/boot /mnt/efi-boot

      wait_for [ -b /dev/disk/by-label/swap ]
      ${util-linux}/bin/swapon /dev/disk/by-label/swap

      [ -d /sys/firmware/efi ] && system="${uefiSystem.config.system.build.toplevel}" || system="${legacySystem.config.system.build.toplevel}"

      ${config.system.build.nixos-install}/bin/nixos-install \
        --system $system \
        --no-root-passwd \
        --cores 0

      if [ ! -d /sys/firmware/efi ]; then
        grub-install --target=i386-pc --boot-directory=/mnt/boot "$dev"
      fi

      ${coreutils-full}/bin/mkdir -p /mnt/root/secrets
      ${coreutils-full}/bin/cp /iso/tailscale_key /mnt/root/secrets/tailscale_key

      ${systemd}/bin/systemctl poweroff
    '';
    serviceConfig = {
      User = "root";
      Type = "oneshot";
    };
  };

  isoImage.contents = [
    {
      source =
        if builtins.pathExists ./tailscale_key then
          ./tailscale_key
        else
          pkgs.writeText "tailscale_key" "No tailscale_key file was provided";
      target = "tailscale_key";
    }
  ];
}
