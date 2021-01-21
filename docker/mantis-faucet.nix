{ lib, mkEnv, dockerTools, writeShellScript, mantis-faucet, coreutils
, gnused, gnugrep, curl, debugUtils }:
let
  entrypoint = writeShellScript "mantis-faucet" ''
    set -exuo pipefail

    case $1 in
      healthcheck)
        test WalletAvailable = "$(
          curl \
            http://$NOMAD_ADDR_rpc \
            -H 'Content-Type: application/json' \
            -X POST \
            -d '{"jsonrpc": "2.0", "method": "faucet_status", "params": [], "id": 1}' \
          | jq -e -r .result.status
        )"
      ;;
      *)
        mkdir -p /tmp
        mkdir -p "$NOMAD_TASK_DIR/mantis"
        mkdir -p "$NOMAD_SECRETS_DIR/keystore"

        cd "$NOMAD_TASK_DIR"

        cp faucet.conf running.conf
        cp "$NOMAD_SECRETS_DIR/account" "$NOMAD_SECRETS_DIR/keystore/UTC--2020-10-16T14-48-29.47Z-$COINBASE"

        chown --reference . --recursive . || true
        ulimit -c unlimited
        exec mantis faucet "-Duser.home=$NOMAD_TASK_DIR" "$@"
      ;;
    esac
  '';
in {
  mantis-faucet = dockerTools.buildLayeredImage {
    name = "docker.mantis.pw/mantis-faucet";
    contents = debugUtils ++ [ coreutils gnugrep gnused mantis-faucet curl ];
    config.Entrypoint = [ entrypoint ];
  };
}
