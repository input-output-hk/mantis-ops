{ namespace
, lib
, mkMantis
, mantis-source
, miners
, config
, genesisJson
}:

count:

let
  name = "${namespace}-mantis-passive";
in mkMantis {
  inherit name;
  serviceName = name;
  resources = {
    # For c5.2xlarge in clusters/mantis/testnet/default.nix, the url ref below
    # provides 3.4 GHz * 8 vCPU = 27.2 GHz max.  80% is 21760 MHz.
    # Allocating by vCPU or core quantity not yet available.
    # Ref: https://github.com/hashicorp/nomad/blob/master/client/fingerprint/env_aws.go
    cpu = 500;
    memoryMB = 5 * 1024;
  };

  tags = [ namespace "passive" ];

  inherit count;

  requiredPeerCount = builtins.length miners;

  services."${name}-rpc" = {
    addressMode = "host";
    tags = [ "rpc" namespace name mantis-source.rev ];
    portLabel = "rpc";
  };

  templates = [
    {
      data = config {
        inherit namespace name;
        miningEnabled = false;
      };
      changeMode = "noop";
      destination = "local/mantis.conf";
      splay = "15m";
    }
    genesisJson
  ];
}

