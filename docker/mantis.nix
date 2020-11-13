{ lib, mkEnv, buildLayeredImage, writeShellScript, mantis, mantis-faucet, coreutils, gnused, gnugrep }:
let
  mantis-entrypoint = writeShellScript "mantis" ''
    set -exuo pipefail

    mkdir -p /tmp
    mkdir -p "$NOMAD_TASK_DIR/mantis"
    cd "$NOMAD_TASK_DIR"

    set +x
    echo "waiting for $REQUIRED_PEER_COUNT peers"
    until [ "$(grep -c enode mantis.conf)" -ge "$REQUIRED_PEER_COUNT" ]; do
      sleep 0.1
    done
    set -x

    cp "mantis.conf" running.conf
    chown --reference . --recursive . || true
    ulimit -c unlimited
    exec mantis "-Duser.home=$NOMAD_TASK_DIR" "$@"
  '';

  faucet-entrypoint = writeShellScript "mantis-faucet" ''
    set -exuo pipefail

    mkdir -p /tmp
    mkdir -p "$NOMAD_TASK_DIR/mantis"
    mkdir -p "$NOMAD_SECRETS_DIR/keystore"

    cd "$NOMAD_TASK_DIR"

    cp faucet.conf running.conf
    cp "$NOMAD_SECRETS_DIR/account" "$NOMAD_SECRETS_DIR/keystore/UTC--2020-10-16T14-48-29.47Z-$COINBASE"

    chown --reference . --recursive . || true
    ulimit -c unlimited
    exec mantis "-Duser.home=$NOMAD_TASK_DIR" "$@"
  '';
in {
  mantis = buildLayeredImage {
    name = "docker.mantis.ws/mantis";
    config = {
      Entrypoint = [ mantis-entrypoint ];

      Env = mkEnv { PATH = lib.makeBinPath [ coreutils gnugrep gnused mantis ]; };
    };
  };

  mantis-faucet = buildLayeredImage {
    name = "docker.mantis.ws/mantis-faucet";
    config = {
      Entrypoint = [ faucet-entrypoint ];

      Env = mkEnv { PATH = lib.makeBinPath [ coreutils gnugrep gnused mantis-faucet ]; };
    };
  };
}
