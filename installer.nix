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

      install_legacy() {
        echo "Legacy/BIOS system detected"

        if [ ! -b /dev/sda ]; then
          echo "Cannot find drive to install on, aborting"
          exit 1
        fi

        ${parted}/bin/parted -s /dev/sda -- mklabel msdos
        ${parted}/bin/parted -s /dev/sda -- mkpart primary 1MB -8GB
        ${parted}/bin/parted -s /dev/sda -- set 1 boot on
        ${parted}/bin/parted -s /dev/sda -- mkpart primary linux-swap -8GB 100%

        ${coreutils-full}/bin/sync

        ${e2fsprogs}/bin/mkfs.ext4 -L nixos /dev/sda1

        ${util-linux}/bin/mkswap -L swap /dev/sda2

        ${coreutils-full}/bin/sync

        wait_for [ -b /dev/disk/by-label/nixos ]
        mount /dev/disk/by-label/nixos /mnt

        ${util-linux}/bin/swapon /dev/sda2

        ${config.system.build.nixos-install}/bin/nixos-install \
          --system ${legacySystem.config.system.build.toplevel} \
          --no-root-passwd \
          --cores 0

        ${coreutils-full}/bin/mkdir -p /mnt/root/secrets
        ${coreutils-full}/bin/cp /iso/tailscale_key /mnt/root/secrets/tailscale_key
      }

      install_uefi() {
        echo "UEFI system detected"

        [ -b /dev/sda ] && dev=/dev/sda
        [ -b /dev/nvme0n1 ] && dev=/dev/nvme0n1

        if [ -z ''${dev+x} ]; then
          echo "Cannot find drive to install on, aborting"
          exit 1
        else
          echo "Erasing $dev and installing Wind Tunnel Runner NixOS"
        fi

        ${parted}/bin/parted -s "$dev" -- mklabel gpt
        ${parted}/bin/parted -s "$dev" -- mkpart root ext4 512MB -8GB
        ${parted}/bin/parted -s "$dev" -- name 1 nixos
        ${parted}/bin/parted -s "$dev" -- mkpart swap linux-swap -8GB 100%
        ${parted}/bin/parted -s "$dev" -- name 2 swap
        ${parted}/bin/parted -s "$dev" -- mkpart ESP fat32 1MB 512MB
        ${parted}/bin/parted -s "$dev" -- name 3 boot
        ${parted}/bin/parted -s "$dev" -- set 3 esp on

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
        ${coreutils-full}/bin/mkdir -p /mnt/boot
        mount -o umask=077 /dev/disk/by-label/boot /mnt/boot

        wait_for [ -b /dev/disk/by-label/swap ]
        ${util-linux}/bin/swapon /dev/disk/by-label/swap

        ${config.system.build.nixos-install}/bin/nixos-install \
          --system ${uefiSystem.config.system.build.toplevel} \
          --no-root-passwd \
          --cores 0

        ${coreutils-full}/bin/mkdir -p /mnt/root/secrets
        ${coreutils-full}/bin/cp /iso/tailscale_key /mnt/root/secrets/tailscale_key
      }

      [ -d /sys/firmware/efi/efivars ] && install_uefi || install_legacy

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
