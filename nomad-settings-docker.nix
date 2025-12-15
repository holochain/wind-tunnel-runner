let
  base = import ./nomad-settings.nix;
in
base // {
  client = base.client // {
    node_pool = "docker";
  };
}
