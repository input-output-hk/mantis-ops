{ mkNomadJob, systemdSandbox, writeShellScript, writeText, coreutils, lib
, cacert, jq, gnused, mantis, mantis-source, dnsutils, gnugrep, iproute, lsof
, netcat, nettools, procps, curl, gawk, telegraf, webfs, mantis-explorer }:
let
  # NOTE: Copy this file and change the next line if you want to start your own cluster!
  prefix = "testnet";

  minerResources = {
    # For c5.2xlarge in clusters/mantis/testnet/default.nix, the url ref below
    # provides 3.4 GHz * 8 vCPU = 27.2 GHz max.  80% is 21760 MHz.
    # Allocating by vCPU or core quantity not yet available.
    # Ref: https://github.com/hashicorp/nomad/blob/master/client/fingerprint/env_aws.go
    cpu = 21760;
    memoryMB = 8 * 1024;
    networks = [{
      dynamicPorts =
        [ { label = "rpc"; } { label = "server"; } { label = "metrics"; } ];
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

  genesisJson = {
    data = ''
      {{- with secret "kv/nomad-cluster/${prefix}/genesis" -}}
      {{.Data.data | toJSON }}
      {{- end -}}
    '';
    changeMode = "restart";
    destination = "local/genesis.json";
  };

  run-mantis = { requiredPeerCount }:
    writeShellScript "mantis" ''
      set -exuo pipefail
      export PATH=${lib.makeBinPath [ jq coreutils gnused gnugrep mantis ]}

      mkdir -p "$NOMAD_TASK_DIR"/{mantis,rocksdb,logs}
      cd "$NOMAD_TASK_DIR"

      set +x
      echo "waiting for ${toString requiredPeerCount} peers"
      until [ "$(grep -c enode mantis.conf)" -ge ${
        toString requiredPeerCount
      } ]; do
        sleep 0.1
      done
      set -x

      cp "mantis.conf" running.conf

      chown --reference . --recursive . || true

      env

      cat "$NOMAD_TASK_DIR/genesis.json"

      ulimit -c unlimited

      exec mantis "-Duser.home=$NOMAD_TASK_DIR" "-Dconfig.file=$NOMAD_TASK_DIR/running.conf"
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

  templatesFor = { name ? null, mining-enabled ? false }:
    let secret = key: ''{{ with secret "${key}" }}{{.Data.data.value}}{{end}}'';
    in [
      {
        data = ''
          include "${mantis}/conf/testnet-internal.conf"

          logging.json-output = true
          logging.logs-file = "logs"

          mantis.blockchains.testnet-internal.bootstrap-nodes = [
            {{ range service "${prefix}-mantis-miner" -}}
              "enode://  {{- with secret (printf "kv/data/nomad-cluster/${prefix}/%s/enode-hash" .ServiceMeta.Name) -}}
                {{- .Data.data.value -}}
                {{- end -}}@{{ .Address }}:{{ .Port }}",
            {{ end -}}
          ]

          mantis.client-id = "${name}"
          mantis.consensus.coinbase = "{{ with secret "kv/data/nomad-cluster/${prefix}/${name}/coinbase" }}{{ .Data.data.value }}{{ end }}"
          mantis.node-key-file = "{{ env "NOMAD_SECRETS_DIR" }}/secret-key"
          mantis.datadir = "{{ env "NOMAD_TASK_DIR" }}/mantis"
          mantis.ethash.ethash-dir = "{{ env "NOMAD_TASK_DIR" }}/ethash"
          mantis.metrics.enabled = true
          mantis.metrics.port = {{ env "NOMAD_PORT_metrics" }}
          mantis.network.rpc.http.interface = "0.0.0.0"
          mantis.network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}
          mantis.network.server-address.port = {{ env "NOMAD_PORT_server" }}
          mantis.blockchains.testnet-internal.custom-genesis-file = "{{ env "NOMAD_TASK_DIR" }}/genesis.json"
        '';
        destination = "local/mantis.conf";
        changeMode = "noop";
      }
      genesisJson
    ] ++ (lib.optional mining-enabled {
      data = ''
        ${secret "kv/data/nomad-cluster/${prefix}/${name}/secret-key"}
        ${secret "kv/data/nomad-cluster/${prefix}/${name}/enode-hash"}
      '';
      destination = "secrets/secret-key";
    });

  mkMantis = { name, resources, ephemeralDisk, count ? 1, templates, serviceName
    , tags ? [ ], extraEnvironmentVariables ? [ ], meta ? { }, constraints ? [ ]
    , requiredPeerCount }: {
      inherit ephemeralDisk count constraints;

      reschedulePolicy = {
        attempts = 0;
        unlimited = false;
      };

      tasks."${name}-telegraf" = systemdSandbox {
        name = "${name}-telegraf";

        vault.policies = [ "nomad-cluster" ];

        command = writeShellScript "telegraf" ''
          set -exuo pipefail

          ${coreutils}/bin/env

          exec ${telegraf}/bin/telegraf -config $NOMAD_TASK_DIR/telegraf.config
        '';

        templates = [{
          data = ''
            [agent]
            flush_interval = "10s"
            interval = "10s"
            omit_hostname = false

            [global_tags]
            client_id = "${name}"

            [inputs.prometheus]
            metric_version = 1
            urls = [ "http://{{ env "NOMAD_ADDR_${
              lib.replaceStrings [ "-" ] [ "_" ] name
            }_metrics" }}" ]

            [outputs.influxdb]
            database = "telegraf"
            urls = ["http://monitoring.node.consul:8428"]
          '';
          destination = "local/telegraf.config";
        }];
      };

      tasks.${name} = systemdSandbox {
        inherit name env resources templates extraEnvironmentVariables;
        command = run-mantis { inherit requiredPeerCount; };
        vault.policies = [ "nomad-cluster" ];

        restartPolicy = {
          interval = "30m";
          attempts = 1;
          delay = "1m";
          mode = "fail";
        };

        services."${serviceName}-prometheus" = {
          tags = [ prefix "prometheus" ];
          portLabel = "metrics";
        };

        services."${serviceName}-rpc" = {
          tags = [ prefix "rpc" serviceName name ];
          portLabel = "rpc";
        };

        services.${serviceName} = {
          tags = [ serviceName mantis-source.rev ] ++ tags;
          meta = {
            inherit name;
            publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          } // meta;
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

  mkMiner = { name, publicPort, requiredPeerCount ? 0, instanceId ? null }:
    lib.nameValuePair name (mkMantis {
      resources = minerResources;
      inherit ephemeralDisk name requiredPeerCount;
      templates = templatesFor {
        inherit name;
        mining-enabled = true;
      };
      serviceName = "${prefix}-mantis-miner";
      tags = [ prefix "public" name ];
      meta = {
        path = "/";
        domain = "${name}.mantis.ws";
        port = toString publicPort;
      };
    });

  mkPassive = count:
    mkMantis {
      name = "${prefix}-mantis-passive";
      serviceName = "${prefix}-mantis-passive";
      resources = passiveResources;
      tags = [ prefix "passive" ];
      inherit count;
      requiredPeerCount = builtins.length miners;
      ephemeralDisk = { sizeMB = 1000; };
      templates = [
        {
          data = ''
            include "${mantis}/conf/testnet-internal.conf"

            logging.json-output = true
            logging.logs-file = "logs"

            mantis.blockchains.testnet-internal.bootstrap-nodes = [
              {{ range service "${prefix}-mantis-miner" -}}
                "enode://  {{- with secret (printf "kv/data/nomad-cluster/${prefix}/%s/enode-hash" .ServiceMeta.Name) -}}
                  {{- .Data.data.value -}}
                  {{- end -}}@{{ .Address }}:{{ .Port }}",
              {{ end -}}
            ]

            mantis.client-id = "${prefix}-mantis-passive"
            mantis.consensus.mining-enabled = false
            mantis.datadir = "{{ env "NOMAD_TASK_DIR" }}/mantis"
            mantis.ethash.ethash-dir = "{{ env "NOMAD_TASK_DIR" }}/ethash"
            mantis.metrics.enabled = true
            mantis.metrics.port = {{ env "NOMAD_PORT_metrics" }}
            mantis.network.rpc.http.interface = "0.0.0.0"
            mantis.network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}
            mantis.network.server-address.port = {{ env "NOMAD_PORT_server" }}
            mantis.blockchains.testnet-internal.custom-genesis-file = "{{ env "NOMAD_TASK_DIR" }}/genesis.json"
          '';
          changeMode = "restart";
          destination = "local/mantis.conf";
        }
        genesisJson
      ];
    };

  amountOfMiners = 1;

  miners = lib.forEach (lib.range 1 amountOfMiners) (num: {
    name = "${prefix}-mantis-${toString num}";
    requiredPeerCount = num - 1;
    publicPort = 9000 + num; # routed through haproxy/ingress
  });

  explorer = let name = "${prefix}-explorer";
  in {
    tasks.${name} = systemdSandbox {
      inherit name;
      env = {
        PATH = lib.makeBinPath [
          coreutils
          # nginx
          webfs
        ];
      };

      resources = { networks = [{ dynamicPorts = [{ label = "http"; }]; }]; };

      command = writeShellScript "mantis-explorer-server" ''
        set -euxo pipefail
        exec webfsd -F -j -p $NOMAD_PORT_http -r ${mantis-explorer} -f index.html
      '';

      services."${name}" = {
        tags = [ "${name}" ];
        meta = {
          inherit name;
          publicIp = "\${attr.unique.platform.aws.public-ipv4}";
        };
        portLabel = "http";
        checks = [{
          type = "http";
          path = "/";
          portLabel = "http";

          checkRestart = {
            limit = 5;
            grace = "300s";
            ignoreWarnings = false;
          };
        }];
      };
    };
  };

  faucetName = "${prefix}-mantis-faucet";
  faucet = {
    tasks.${faucetName} = systemdSandbox {
      name = faucetName;
      env = { PATH = lib.makeBinPath [ coreutils mantis ]; };

      vault.policies = [ "nomad-cluster" ];

      resources = { networks = [{ dynamicPorts = [{ label = "rpc"; }]; }]; };
      extraEnvironmentVariables = [ "COINBASE" ];

      templates = let
        secret = key: ''{{ with secret "${key}" }}{{.Data.data.value}}{{end}}'';
      in [
        {
          data = ''
            include "${mantis}/conf/testnet-internal.conf"
            mantis.blockchains.testnet-internal.custom-genesis-file = "{{ env "NOMAD_TASK_DIR" }}/genesis.json"

            faucet {
              # Base directory where all the data used by the faucet is stored
              datadir = {{ env "NOMAD_TASK_DIR" }}/mantis-faucet

              # Wallet address used to send transactions from
              wallet-address =
                {{- with secret "kv/nomad-cluster/${prefix}/${prefix}-mantis-1/coinbase" -}}
                  "{{.Data.data.value}}"
                {{- end }}

              # Password to unlock faucet wallet
              wallet-password = ""

              # Path to directory where wallet key is stored
              keystore-dir = {{ env "NOMAD_SECRETS_DIR" }}/keystore

              # Transaction gas price
              tx-gas-price = 20000000000

              # Transaction gas limit
              tx-gas-limit = 90000

              # Transaction value
              tx-value = 1000000000000000000

              # Faucet listen interface
              listen-interface = "0.0.0.0"

              # Faucet listen port
              listen-port = {{ env "NOMAD_PORT_rpc" }}

              # Faucet cors config
              cors-allowed-origins = "*"

              # Address of Ethereum node used to send the transaction
              rpc-address = {{- range service "${prefix}-mantis-1.${prefix}-mantis-miner-rpc" -}}
                  "http://{{ .Address }}:{{ .Port }}"
                {{- end }}

              # How often can a single IP address send a request
              min-request-interval = 1.minute

              # How many ip addr -> timestamp entries to store
              latest-timestamp-cache-size = 1024
            }

            logging {
              # Flag used to switch logs to the JSON format
              json-output = false

              # Logs directory
              logs-dir = {{ env "NOMAD_TASK_DIR" }}/mantis-faucet/logs

              # Logs filename
              logs-file = "logs"
            }
          '';
          changeMode = "noop";
          destination = "local/faucet.conf";
        }
        genesisJson
        {
          data = ''
            {{- with secret "kv/data/nomad-cluster/${prefix}/${prefix}-mantis-1/account" -}}
            {{.Data.data | toJSON }}
            {{- end -}}
          '';
          destination = "secrets/account";
        }
        {
          data = ''
            COINBASE={{- with secret "kv/data/nomad-cluster/${prefix}/${prefix}-mantis-1/coinbase" -}}{{ .Data.data.value }}{{- end -}}
          '';
          destination = "secrets/env";
          env = true;
        }
      ];

      command = writeShellScript "mantis-faucet" ''
        set -exuo pipefail
        export PATH=${lib.makeBinPath [ jq coreutils gnused gnugrep mantis ]}

        mkdir -p "$NOMAD_TASK_DIR"/{mantis-faucet,logs}
        mkdir -p "$NOMAD_SECRETS_DIR/keystore"
        cd "$NOMAD_TASK_DIR"

        cp faucet.conf running.conf
        cp "$NOMAD_SECRETS_DIR/account" "$NOMAD_SECRETS_DIR/keystore/UTC--2020-10-16T14-48-29.47Z-$COINBASE"

        cat "$NOMAD_SECRETS_DIR/keystore/UTC--2020-10-16T14-48-29.47Z-$COINBASE"

        chown --reference . --recursive . || true

        ulimit -c unlimited

        exec faucet-server "-Duser.home=$NOMAD_TASK_DIR" "-Dconfig.file=$NOMAD_TASK_DIR/running.conf"
      '';

      services."${faucetName}" = {
        tags = [ "${faucetName}" ];
        meta = {
          name = faucetName;
          publicIp = "\${attr.unique.platform.aws.public-ipv4}";
        };
        portLabel = "rpc";
      };
    };
  };

in {
  "${prefix}-mantis" = mkNomadJob "${prefix}-mantis" {
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

    taskGroups = (lib.listToAttrs (map mkMiner miners)) // {
      "${prefix}-mantis-passive" = mkPassive 2;
    };
  };

  "${prefix}-mantis-explorer" = mkNomadJob "${prefix}-mantis-explorer" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";

    taskGroups."${prefix}-explorer" = explorer;
  };

  "${faucetName}" = mkNomadJob "${faucetName}" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";

    taskGroups."${faucetName}" = faucet;
  };
}
