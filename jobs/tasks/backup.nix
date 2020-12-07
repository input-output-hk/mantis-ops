{ lib, dockerImages, namespace, name, mantis }: {
  networks = [{
    mode = "bridge";
    ports = {
      metrics.to = 6000;
      rpc.to = 7000;
      server.to = 8000;
    };
  }];

  tasks.backup = {
    driver = "docker";

    vault = {
      policies = [ "nomad-cluster" ];
      changeMode = "restart";
    };

    resources = {
      cpu = 500;
      memoryMB = 5 * 1024;
    };

    config = {
      image = dockerImages.backup.id;
      args = [ "--tag" namespace ];
      ports = [ "metrics" "server" "rpc" ];

      labels = [{
        inherit namespace name;
        imageTag = dockerImages.backup.image.imageTag;
      }];

      logging = {
        type = "journald";
        config = [{
          tag = name;
          labels = "name,namespace,imageTag";
        }];
      };
    };

    templates = [
      {
        data = ''
          AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
          AWS_DEFAULT_REGION="us-east-1"
          AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
          RESTIC_PASSWORD="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.password}}{{end}}"
          RESTIC_REPOSITORY="s3:http://{{ with node "monitoring" }}{{ .Node.Address }}{{ end }}:9000/restic"
          MONITORING_URL="http://{{ with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428/api/v1/query"
        '';
        env = true;
        destination = "secrets/env.txt";
      }
      {
        data = ''
          include "${mantis}/conf/testnet-internal-nomad.conf"

          logging.json-output = true
          logging.logs-file = "logs"

          mantis.blockchains.testnet-internal-nomad.bootstrap-nodes = [
            {{ range service "${namespace}-mantis-miner-server" -}}
              "enode://  {{- with secret (printf "kv/data/nomad-cluster/${namespace}/%s/enode-hash" .ServiceMeta.Name) -}}
                {{- .Data.data.value -}}
                {{- end -}}@{{ .Address }}:{{ .Port }}",
            {{ end -}}
          ]

          mantis.blockchains.testnet-internal-nomad.checkpoint-public-keys = [
            ${
              lib.concatMapStringsSep "," (x: ''
                {{- with secret "kv/data/nomad-cluster/${namespace}/obft-node-${
                  toString x
                }/obft-public-key" -}}"{{- .Data.data.value -}}"{{end}}
              '') (lib.range 1 5)
            }
          ]

          mantis.client-id = "${name}"
          mantis.consensus.mining-enabled = false
          mantis.datadir = "/local/mantis"
          mantis.ethash.ethash-dir = "/local/ethash"
          mantis.metrics.enabled = true
          mantis.metrics.port = {{ env "NOMAD_PORT_metrics" }}
          mantis.network.peer.long-blacklist-duration = 120
          mantis.network.peer.short-blacklist-duration = 10
          mantis.network.rpc.http.interface = "0.0.0.0"
          mantis.network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}
          mantis.network.server-address.port = {{ env "NOMAD_PORT_server" }}
          mantis.blockchains.testnet-internal-nomad.custom-genesis-file = "{{ env "NOMAD_TASK_DIR" }}/genesis.json"

          mantis.blockchains.testnet-internal-nomad.ecip1098-block-number = 0
          mantis.blockchains.testnet-internal-nomad.ecip1097-block-number = 0
        '';
        changeMode = "noop";
        destination = "local/mantis.conf";
      }
      {
        data = ''
          {{- with secret "kv/nomad-cluster/${namespace}/genesis" -}}
          {{.Data.data | toJSON }}
          {{- end -}}
        '';
        destination = "local/genesis.json";
        changeMode = "noop";
      }
    ];
  };
}
