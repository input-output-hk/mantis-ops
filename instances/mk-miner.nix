{ mkMantis, lib }:

{ name
, publicDiscoveryPort
, publicServerPort
, publicRpcPort
, requiredPeerCount ? 0
, instanceId ? null
}:

lib.nameValuePair name (mkMantis {
  resources = {
    cpu = 4000;
    memoryMB = 5 * 1024;
  };

  inherit name requiredPeerCount;
  templates = [
    {
      data = config {
        inherit publicDiscoveryPort namespace name;
        miningEnabled = true;
      };
      changeMode = "noop";
      destination = "local/mantis.conf";
      splay = "15m";
    }
    {
      data = let
        secret = key:
          ''{{ with secret "${key}" }}{{.Data.data.value}}{{end}}'';
      in ''
        ${secret "kv/data/nomad-cluster/${namespace}/${name}/secret-key"}
        ${secret "kv/data/nomad-cluster/${namespace}/${name}/enode-hash"}
      '';
      destination = "secrets/secret-key";
      changeMode = "restart";
      splay = "15m";
    }
    {
      data = ''
        AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
        AWS_DEFAULT_REGION="us-east-1"
        AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
        MONITORING_ADDR="http://{{ with node "monitoring" }}{{ .Node.Address }}{{ end }}:9000"
        MONITORING_URL="http://{{ with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428/api/v1/query"
        DAG_NAME="full-R23-0000000000000000"
      '';
      env = true;
      destination = "secrets/env.txt";
      changeMode = "noop";
    }
    genesisJson
  ];

  serviceName = "${namespace}-mantis-miner";

  tags = [ "ingress" namespace name ];

  serverMeta = {
    ingressHost = "${name}.${domain}";
    ingressPort = toString publicServerPort;
    ingressBind = "*:${toString publicServerPort}";
    ingressMode = "tcp";
    ingressServer = "_${namespace}-mantis-miner._${name}.service.consul";
  };

  discoveryMeta = {
    ingressHost = "${name}.${domain}";
    ingressPort = toString publicDiscoveryPort;
    ingressBind = "*:${toString publicDiscoveryPort}";
    ingressMode = "tcp";
    ingressServer =
      "_${namespace}-mantis-miner._${name}-discovery.service.consul";
  };

  rpcMeta = {
    ingressHost = "mantis.${domain}";
    ingressPort = toString publicRpcPort;
    ingressBind = "*:443";
    ingressMode = "http";
    ingressServer = "_${namespace}-mantis-miner-rpc._tcp.service.consul";
  };
})
