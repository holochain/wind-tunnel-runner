{
  data_dir = "/var/lib/nomad";
  plugin.raw_exec.config.enabled = true;
  acl.enabled = true;
  client = {
    enabled = true;
    servers = [ "nomad-server-01.holochain.org" ];
    artifact.disable_filesystem_isolation = true;
    node_pool = "default";
  };
}
