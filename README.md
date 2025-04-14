# wind-tunnel-runner

The guide and NixOS configuration for setting up a machine to run Wind Tunnel
scenarios

## Adding a node

### Installing NixOS

Go to <https://nixos.org/download/#nixos-iso> to get the ISO and install NixOS.

Feel free to use any of the installation ISOs but the graphical one is easier.

Follow the NixOS installation guide as normal, create any user you want with
any password as this user will be overwritten by `Colmena` and we will only use
the root account with SSH key access. A graphical desktop environment is
probably not needed so just select `No desktop` when asked.

Once the installation is finished, remove the live-NixOS USB and restart the
system.

### Adding new machine

The first step is to add a new machine "node" with a unique name to the
`Colmena` definition in the [flake.nix](flake.nix).

Do this by adding an entry under `outputs.flake.colmena.<your-machine-name>`.
The entry needs to contain any configuration specific to this new machine, for
example the root directory `fileSystems` entry from the generated
`hardware-configuration.nix` file.

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  perSystem = { ... }: {
    # ...other config...
  };

  flake.colmena =
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

        # ...other machine-specific config here...
      };
    };
};
```

Make sure that your machine's name is unique and add any configuration that
differs from the default. For example, if your boot device is not `/dev/sda`
then change `boot.loader.grub.device` and `fileSystems."/".device` accordingly.

Commit and push these changes to a new branch.

### Registering the new machine

Now that you have a branch with the definition of your new machine on it, make
sure that the machine has internet access, preferably a wired one for
stability.

Then, log into the machine with the root account and run the command:

> \[!Warning\]
> Must use the `root` account as all other accounts will be deleted during
> installation.

```sh
nix --experimental-features 'nix-command flakes' run github:holochain/wind-tunnel-runner/<your-branch> -- <your-machine-name>
```

After the install, you will be prompted to log into Tailscale via a URL.
Navigate to this URL on any device and login with the
`holochain-release-automation2` GitHub account (credentials are in password
manager shared vault).

Now navigate to <https://login.tailscale.com/admin/machines> and confirm that
the new machine is there.

### Disable key expiration

By default all nodes need a new key every 90 days. For these machines it is
recommended to instead set the key to never expire so that we don't need to
manually update the keys.

To do this go to <https://login.tailscale.com/admin/machines> and select the
`...` dropdown on the right of the machine and select `Disable key expiry`.

### Checking the machine in Nomad

Now that the machine is registered on Tailscale, navigate to
<https://nomad-server-01.holochain.org:4646/ui/clients> and check that the
machine is also in the list of available Nomad clients.
