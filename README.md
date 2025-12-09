# wind-tunnel-runner

The guide and NixOS configuration for setting up a machine to run Wind Tunnel
scenarios

The machines that are created and managed by this repository are used as Nomad
clients for testing [Wind Tunnel](https://github.com/holochain/wind-tunnel)
scenarios. They will be part of the Nomad cluster that is managed by the Nomad
server at <http://nomad-server-01.holochain.org:4646>.

The desire is that these machines will always be accessible, be in various
locations, and be of a range of power (CPU speed etc.) as to provide a wide
range of test machines to accurately match a real-world environment.

These machines are designed to be for internal use only and as such the
configuration in this repository should only be used if you are directly
involved. A common machine to be repurposed for this project are HoloPorts and
so there is mention of the HoloPorts in this documentation, but this project is
not officially associated with the HoloPorts and the configuration in this
repository is designed to replace HPOS entirely. Therefore, if you have a
HoloPort and you want to continue to participate in the Holo testing network
then please ignore these instructions.

## Adding a node

### Minimum Hardware Requirements

The minimum hardware requirements for running a node are:

- 10GB Disk
- 4GB RAM
- An internet connection

### Using Auto-installation ISO

Navigate to <https://github.com/holochain/wind-tunnel-runner/releases/latest>
and download the installer ISO, or use
[this download link](https://github.com/holochain/wind-tunnel-runner/releases/latest/download/wind-tunnel-runner-auto-installer.iso).

Create a live USB from the ISO you just download. You can use `dd`, or whatever
tool you prefer.

Make sure that the machine you want to use is connected to the internet via
Ethernet and power it off. Plug in the USB and power the machine back on, you
should see the NixOS installer boot menu, if not, may need to change the boot
order to make sure that the machine boots from the USB first. The
progress/status of the installation will be printed to `tty1` and the
machine will shutdown once the installation is completed successfully. Once it
has shutdown then remove the USB and reboot the machine.

The new machine should be listed on the Tailscale dashboard at
<https://login.tailscale.com/admin/machines> with the note `Needs approval`.
To approve the machine, select the `...` dropdown on the right of the machine
and select `Approve`.

Next, change the name of the machine/node in Tailscale by selecting the `...`
dropdown on the right of the machine and select `Edit machine name...`. The
name should be unique and recognisable so that you know which node belongs to
you, something like `nomad-client-<user>` is common practice with a base-one
index after it, if you have multiple machines, i.e.
`nomad-client-<user>-<index>`.

> [!Note]
> Changing the node name in Tailscale will not immediately change the hostname
> of the machine, but this will happen after a `colmena apply` which happens
> automatically after the PR is merged to `main`.

Finally, add the new machine as a "node" to the Colmena definition in the
[colmena.nix](colmena.nix) file, the name of the machine should match the name
in the Tailscale dashboard.

```nix
inputs:
let
  targetSystem = "x86_64-linux";
in
{
  # ...other config...

  <your-machine-name> = _: { };
}
```

Make sure to add any custom configuration that you want for your machine, this
can be any valid NixOS configuration including things like SSH keys, if you want
local access without using Tailscale, or a Desktop Environment.

Create a PR for your changes and once it is merged then Colmena will manage the
machine for you and you will see it listed as a client in the Nomad dashboard
at <https://nomad-server-01.holochain.org:4646/ui/clients>.

### Using Published Docker Image

> [!WARNING]\
> The wind-tunnel-runner Docker image requires extensive permissions on the
> host machine that are effectively root access. It should only be run on a
> dedicated machine as the sole Docker container.

First, install [Docker](https://docs.docker.com/get-started/get-docker/) on your
machine, and start the Docker service.

Next, pull and run the latest Docker image for the wind-tunnel-runner:

```bash
docker image pull ghcr.io/holochain/wind-tunnel-runner:latest
docker run --cgroupns=host --privileged -d -t --rm ghcr.io/holochain/wind-tunnel-runner:latest
```

The wind-tunnel-runner will now be running. You can view running docker
containers with:

```bash
docker ps
```

### Manually

#### Installing NixOS

Go to <https://nixos.org/download/#nixos-iso> to get the ISO and install NixOS.

Feel free to use any of the installation ISOs but the graphical one is easier.

Follow the NixOS installation guide as normal, create any user you want with
any password as this user will be overwritten by `Colmena` and we will only use
the root account with SSH key access. A graphical desktop environment is
probably not needed so just select `No desktop` when asked.

Once the installation is finished, remove the live-NixOS USB and restart the
system.

#### Adding new machine

The first step is to add a new machine "node" with a unique name to the
`Colmena` definition in the [colmena.nix](colmena.nix).

The entry needs to contain any configuration specific to this new machine, for
example the root directory `fileSystems` entry from the generated
`hardware-configuration.nix` file, usually found in `/etc/nixos`.

```nix
inputs:
let
  targetSystem = "x86_64-linux";
in
{
  # ...other config...

  <your-machine-name> = _: {
    fileSystems."/" = {
      device = "/dev/disk/by-uuid/<uuid-of-main-drive>";
      fsType = "ext4";
    };
  };
}
```

Make sure that your machine's name is unique and add any configuration that
differs from the default.

Commit and push these changes to a new branch.

##### Bootloader

By default, NixOS will install `systemd-boot` as the bootloader for UEFI
systems. We use GRUB as it supports both UEFI and older BIOS systems.

You can find out what bootloader is currently used by checking the generated
`/etc/nixos/hardware-configuration.nix` file and looking for `boot.loader`
options.

If you are currently using `systemd-boot`, then take care to check that GRUB is
used as the priority boot option in your machine's BIOS.

If you would prefer to use `systemd-boot` then override the `boot.loader`
settings for your machine in the Colmena config:

```nix
<your-machine-name> = _: {
  # ...other config...

  boot.loader = {
    grub.enable = false;
    systemd-boot.enable = true;
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
};
```

#### Registering the new machine

Now that you have a branch with the definition of your new machine on it, make
sure that the machine has internet access, preferably a wired one for
stability.

Then, log into the machine with the root account and run the command:

> [!Warning]
> Must use the `root` account as all other accounts will be deleted during
> installation.

```sh
nix --experimental-features 'nix-command flakes' run github:holochain/wind-tunnel-runner/<your-branch> -- <your-machine-name>
```

Now navigate to <https://login.tailscale.com/admin/machines> and confirm that
the new machine is there.

##### Password Access

> [!Warning]
> The password is hashed with a random salt and SSH access is managed via
> Tailscale so it should be safe enough to share. However, know that if you
> allow access to this machine to the public then password access via SSH
> should be disabled.

Once the machine is added as a Colmena node, the password is set under the
defaults section in the [colmena.nix](colmena.nix) file and cannot be changed
manually. You should not need the password as you can SSH via Tailscale without
it but the password is in the password manager's shared vault under
`Nomad Client Root Password`.

###### Changing the Password

To change the password, generate a new one in the password manager's shared
vault and then use `mkpasswd` to generate the hash and set the value of
`users.users.root.hashedPassword` in the `defaults` section of the
[colmena.nix](colmena.nix) to change the password for all nodes.

Alternatively, if you really want a different password for only your node for
easier local access, you can override the default by setting
`users.users.root.hashedPassword` for your node only.

```nix
<your-machine-name> = _: {
  # ...other config...

  users.users.root.hashedPassword = "<password-hash-from-mkpasswd>"
};
```

#### Disable key expiration

By default all nodes need a new key every 90 days. For these machines it is
recommended to instead set the key to never expire so that we don't need to
manually update the keys.

To do this go to <https://login.tailscale.com/admin/machines> and select the
`...` dropdown on the right of the machine and select `Disable key expiry`.

#### Checking the machine in Nomad

Now that the machine is registered on Tailscale, navigate to
<https://nomad-server-01.holochain.org:4646/ui/clients> and check that the
machine is also in the list of available Nomad clients.
