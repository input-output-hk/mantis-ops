{ lib, config, ... }:
{
  services.nomad.client.node_class = "client-${config.asg.region}";
}
