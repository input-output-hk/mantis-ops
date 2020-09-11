{ mkNomadJob, systemdSandbox, writeShellScript, writeText, coreutils, lib
, cacert, jq, gnused, mantis }:
let
  nodeConfig = {
    logging = {
      json-output = true;
      logs-file = "$NOMAD_TASK_DIR/logs";
    };

    # Sample configuration for a custom private testnet.
    mantis = {
      sync = {
        # Whether to enable fast-sync
        do-fast-sync = false;

        # Duration for blacklisting a peer. Blacklisting reason include: invalid response from peer, response time-out, etc.
        # 0 value is a valid duration and it will disable blacklisting completely (which can be useful when all nodes are
        # are controlled by a single party, eg. private networks)
        blacklist-duration = 0;

        # Set to false to disable broadcasting the NewBlockHashes message, as its usefulness is debatable,
        # especially in the context of private networks
        broadcast-new-block-hashes = false;

        pruning.mode = "archive";
      };

      blockchains.network = "private";

      consensus = {
        coinbase =
          "0011223344556677889900112233445566778899"; # has to be changed for each node
        mining-enabled = true;
      };

      network = {
        discovery = {
          # We assume a fixed cluster, so `bootstrap-nodes` must not be empty
          discovery-enabled = false;

          # Listening interface for discovery protocol
          interface = "127.0.0.1";

          # Listening port for discovery protocol
          # port = 30303
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
            interface = "127.0.0.1";

            # Listening port of JSON-RPC HTTP/HTTPS endpoint
            # port = 8546

            # Domains allowed to query RPC endpoint. Use "*" to enable requests from any domain.
            cors-allowed-origins = "*";
          };
        };
      };
    };
  };

  run-mantis = writeShellScript "mantis" ''
    set -exuo pipefail
    export PATH=${lib.makeBinPath [ jq coreutils gnused mantis ]}

    cd $NOMAD_TASK_DIR
    mkdir -p  logs

    coinbase="$(tr -dc '0-9' < /dev/random | fold -w 40 | head -n 1)"

    jq . < ${writeText "name.json" (builtins.toJSON nodeConfig)} \
    | jq --arg var "$NOMAD_TASK_DIR/logs" '.logging."logs-dir" = $var' \
    | jq --arg var "$coinbase" '.mantis.consensus.coinbase = $var' \
    | head -c -2 \
    | tail -c +2 \
    | sed 's/^  //' \
    > node.conf.custom

    cat <<EOF > node.conf
    include "${mantis}/conf/mantis.conf"
    EOF

    cat node.conf.custom >> node.conf
    ulimit -c unlimited

    cat node.conf

    exec mantis-core -Dconfig.file=$NOMAD_TASK_DIR/node.conf
  '';
in {
  mantis = mkNomadJob "mantis" {
    datacenters = [ "us-east-2" ];
    type = "service";

    taskGroups.mantis = {
      count = 1;

      services.mantis = { };

      tasks.mantis = systemdSandbox {
        name = "mantis";

        command = run-mantis;

        env = {
          PATH = lib.makeBinPath [ coreutils ];
        };

        resources = {
          cpu = 100;
          memoryMB = 1024;
        };
      };
    };
  };
}
