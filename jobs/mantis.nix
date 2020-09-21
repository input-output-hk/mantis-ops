{ mkNomadJob, systemdSandbox, writeShellScript, writeText, coreutils, lib
, cacert, jq, gnused, mantis, dnsutils, gnugrep, iproute, lsof, netcat, nettools
, procps }:
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

    export HOME="$NOMAD_TASK_DIR"
    cd $HOME
    mkdir -p logs

    ls -la
    id
    chown --reference . --recursive .

    jq . < ${writeText "name.json" (builtins.toJSON nodeConfig)} \
    | jq --arg var "$HOME/logs" '.logging."logs-dir" = $var' \
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

    exec mantis-core "-Duser.home=$HOME" "-Dconfig.file=$HOME/node.conf"
  '';
in {
  mantis = mkNomadJob "mantis" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";

    taskGroups.mantis = {
      count = 2;

      services.mantis = { };

      ephemeralDisk = {
        # Std client disk size is set as gp2, 100 GB SSD in bitte at
        # modules/terraform/clients.nix
        sizeMB = 60 * 1000;
      };

      tasks.mantis = systemdSandbox {
        name = "mantis";

        command = run-mantis;

        env = {
          # Adds some extra commands to the store and path for debugging inside
          # nomad jobs with `nomad alloc exec $ALLOC_ID /bin/sh`
          PATH = lib.makeBinPath [
            coreutils
            dnsutils
            gnugrep
            iproute
            jq
            lsof
            netcat
            nettools
            procps
          ];
        };

        resources = {
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
                value = 9079;
              }
              {
                label = "discovery";
                value = 30303;
              }
            ];
          }];
        };
      };
    };
  };
}
