{ mkNomadJob, systemdSandbox, writeShellScript, writeText, coreutils, lib
, cacert, jq, gnused, mantis, mantis-source, dnsutils, gnugrep, iproute, lsof
, netcat, nettools, procps, curl, gawk }:
let

  passiveConfig = lib.recursiveUpdate minerConfig {
    mantis.consensus.mining-enabled = false;
  };

  minerConfig = {
    logging.json-output = true;

    # Sample configuration for a custom private testnet.
    mantis = {
      blockchains.network = "testnet-internal";

      metrics = {
        # Set to `true` iff your deployment supports metrics collection.
        # We expose metrics using a Prometheus server
        # We default to `false` here because we do not expect all deployments to support metrics collection.
        enabled = true;

        # The port for setting up a Prometheus server over localhost.
        port = 13798;
      };

      sync = {
        # Whether to enable fast-sync
        do-fast-sync = false;

        # Duration for blacklisting a peer. Blacklisting reason include: invalid response from peer, response time-out, etc.
        # 0 value is a valid duration and it will disable blacklisting completely (which can be useful when all nodes are
        # are controlled by a single party, eg. private networks)
        blacklist-duration = 0;

        pruning.mode = "archive";
      };

      consensus.mining-enabled = true;

      network = {
        discovery = {
          # We assume a fixed cluster, so `bootstrap-nodes` must not be empty
          discovery-enabled = false;

          # Listening interface for discovery protocol
          interface = "0.0.0.0";

          # Listening port for discovery protocol
          port = 30303;
        };

        peer = {
          short-blacklist-duration = 0;
          long-blacklist-duration = 0;
        };

        rpc = {
          http = {
            # JSON-RPC mode
            # Available modes are: http, https
            # Choosing https requires creating a certificate and setting up 'certificate-keystore-path' and
            # 'certificate-password-file'
            # See: https://github.com/input-output-hk/mantis/wiki/Creating-self-signed-certificate-for-using-JSON-RPC-with-HTTPS
            mode = "http";

            # Listening address of JSON-RPC HTTP/HTTPS endpoint
            interface = "0.0.0.0";

            # Listening port of JSON-RPC HTTP/HTTPS endpoint
            port = 8546;

            # Domains allowed to query RPC endpoint. Use "*" to enable requests from any domain.
            cors-allowed-origins = "*";
          };
        };
      };
    };
  };

  minerResources = {
    # For c5.2xlarge in clusters/mantis/testnet/default.nix, the url ref below
    # provides 3.4 GHz * 8 vCPU = 27.2 GHz max.  80% is 21760 MHz.
    # Allocating by vCPU or core quantity not yet available.
    # Ref: https://github.com/hashicorp/nomad/blob/master/client/fingerprint/env_aws.go
    cpu = 21760;
    memoryMB = 8 * 1024;
    networks = [{
      reservedPorts = [
        {
          label = "rpc";
          value = 8546;
        }
        {
          label = "server";
          value = 9076;
        }
        {
          label = "metrics";
          value = 13798;
        }
      ];
    }];
  };

  passiveResources = {
    # For c5.2xlarge in clusters/mantis/testnet/default.nix, the url ref below
    # provides 3.4 GHz * 8 vCPU = 27.2 GHz max.  80% is 21760 MHz.
    # Allocating by vCPU or core quantity not yet available.
    # Ref: https://github.com/hashicorp/nomad/blob/master/client/fingerprint/env_aws.go
    cpu = 500;
    memoryMB = 3 * 1024;
    networks = [{
      dynamicPorts =
        [ { label = "rpc"; } { label = "server"; } { label = "metrics"; } ];
    }];
  };

  ephemeralDisk = {
    # Std client disk size is set as gp2, 100 GB SSD in bitte at
    # modules/terraform/clients.nix
    sizeMB = 10 * 1000;
    # migrate = true;
    # sticky = true;
  };

  run-mantis = baseConfig:
    writeShellScript "mantis" ''
      set -exuo pipefail
      export PATH=${lib.makeBinPath [ jq coreutils gnused mantis ]}

      mkdir -p "$NOMAD_TASK_DIR/mantis"
      cd "$NOMAD_TASK_DIR"

      ls -laR "$NOMAD_TASK_DIR"

      chown --reference . --recursive . || true

      env

      echo "NOMAD_PORT_server  = $NOMAD_PORT_server"
      echo "NOMAD_PORT_metrics = $NOMAD_PORT_metrics"
      echo "NOMAD_PORT_rpc     = $NOMAD_PORT_rpc"
      ENODE_HASH="''${ENODE_HASH:-}"

      coinbase="$(echo "$ENODE_HASH" | sha256sum - | fold -w 40 | head -n 1)"

      jq . < ${writeText "mantis.json" (builtins.toJSON baseConfig)} \
      | jq '.logging."logs-file" = "logs"' \
      | jq --arg var "$NOMAD_TASK_DIR/ethash" '.mantis.ethash."ethash-dir" = $var' \
      | jq --arg var "$coinbase" '.mantis.consensus.coinbase = $var' \
      | jq --arg var "$NOMAD_TASK_DIR/mantis" '.mantis.datadir = $var' \
      | jq --arg var "$NOMAD_SECRETS_DIR/secret-key" '.mantis."node-key-file" = $var' \
      | jq --arg var "$NOMAD_PORT_rpc" '.mantis.network.rpc.http.port = $var' \
      | jq --arg var "$NOMAD_PORT_metrics" '.mantis.metrics.port = $var' \
      | jq --arg var "$NOMAD_PORT_server" '.mantis.network."server-address".port = $var' \
      | head -c -2 \
      | tail -c +2 \
      | sed 's/^  //' \
      > node.conf.custom

      cat <<EOF > node.conf
      include "${mantis}/conf/testnet-internal.conf"
      EOF

      cat node.conf.custom >> node.conf
      echo 'include "bootstrap-nodes.conf"' >> node.conf

      ulimit -c unlimited

      ls -laR

      exec mantis "-Duser.home=$NOMAD_TASK_DIR" "-Dconfig.file=$NOMAD_TASK_DIR/node.conf"
    '';

  env = {
    # Adds some extra commands to the store and path for debugging inside
    # nomad jobs with `nomad alloc exec $ALLOC_ID /bin/sh`
    PATH = lib.makeBinPath [
      coreutils
      curl
      dnsutils
      gawk
      gnugrep
      iproute
      jq
      lsof
      netcat
      nettools
      procps
    ];
  };

  templatesForMiner = name:
    let secret = key: ''{{ with secret "${key}" }}{{.Data.data.value}}{{end}}'';
    in [
      {
        data = ''
          ENODE_HASH=${
            secret "kv/data/nomad-cluster/testnet/${name}/enode-hash"
          }
        '';
        env = true;
        destination = "secrets/env";
        changeMode = "noop";
      }
      {
        data = ''
          ${secret "kv/data/nomad-cluster/testnet/${name}/secret-key"}
          ${secret "kv/data/nomad-cluster/testnet/${name}/enode-hash"}
        '';
        destination = "secrets/secret-key";
      }
      {
        data = ''
          mantis.blockchains.testnet-internal.bootstrap-nodes = [
          {{ range service "mantis-miner" -}}
            "enode://  {{- with secret (printf "kv/data/nomad-cluster/testnet/%s/enode-hash" .ServiceMeta.Name) -}}
              {{- .Data.data.value -}}
              {{- end -}}@{{ .Address }}:{{ .Port }}",
          {{ end -}}
          ]
        '';
        changeMode = "noop";
        destination = "local/bootstrap-nodes.conf";
      }
    ];

  mkMantis = { name, config, resources, ephemeralDisk, count ? 1, templates
    , serviceName, tags ? [ ], extraEnvironmentVariables ? [ ] }: {
      inherit ephemeralDisk count;

      tasks.${name} = systemdSandbox {
        inherit name env resources templates;
        command = run-mantis config;
        vault.policies = [ "nomad-cluster" ];

        restart = {
          interval = "1m";
          attempts = 60;
          delay = "1m";
          mode = "fail";
        };

        services.${serviceName} = {
          tags = [ serviceName mantis-source.rev ] ++ tags;
          meta.name = name;
          portLabel = "server";
          checks = [{
            type = "http";
            path = "/healthcheck";
            portLabel = "rpc";

            checkRestart = {
              limit = 5;
              grace = "300s";
              ignoreWarnings = false;
            };
          }];
        };
      };
    };

  mkMiner = name:
    mkMantis {
      config = minerConfig;
      resources = minerResources;
      inherit ephemeralDisk name;
      templates = templatesForMiner name;
      extraEnvironmentVariables = [ "ENODE_HASH" ];
      serviceName = "mantis-miner";
    };

in {
  mantis = mkNomadJob "mantis" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";

    update = {
      maxParallel = 1;
      # healthCheck = "checks"
      minHealthyTime = "10s";
      healthyDeadline = "5m";
      progressDeadline = "10m";
      autoRevert = true;
      autoPromote = false;
      canary = 0;
      stagger = "30s";
    };

    taskGroups.mantis-1 = mkMiner "mantis-1";
    taskGroups.mantis-2 = mkMiner "mantis-2";
    taskGroups.mantis-3 = mkMiner "mantis-3";
    taskGroups.mantis-4 = mkMiner "mantis-4";

    taskGroups.mantis-passive = mkMantis {
      name = "mantis-passive";
      serviceName = "mantis-passive";
      config = passiveConfig;
      resources = passiveResources;
      tags = [ "passive" ];
      count = 2;
      ephemeralDisk = { sizeMB = 1000; };
      templates = [{
        data = ''
          mantis.blockchains.testnet-internal.bootstrap-nodes = [
          {{ range service "mantis-miner" -}}
            "enode://  {{- with secret (printf "kv/data/nomad-cluster/testnet/%s/enode-hash" .ServiceMeta.Name) -}}
              {{- .Data.data.value -}}
              {{- end -}}@{{ .Address }}:{{ .Port }}",
          {{ end -}}
          ]
        '';
        changeMode = "noop";
        destination = "local/bootstrap-nodes.conf";
      }];
    };
  };
}
