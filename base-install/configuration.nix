{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Allow proprietary/unfree packages to be installed
  nixpkgs.config.allowUnfree = true;

  # Nix configuration
  nix = {
    # Set nixpkgs version to the latest unstable version
    package = pkgs.nixVersions.latest;

    # Enable the `nix` command and `flakes`
    extraOptions = "experimental-features = nix-command flakes";
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  networking.hostName = "nixos-vm";

  users.mutableUsers = false;
  users.extraUsers.root.password = "init";

  system.stateVersion = "24.11";
}
