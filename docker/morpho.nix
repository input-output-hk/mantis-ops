{ lib, buildLayeredImage, mkEnv, morpho-node, coreutils, gnused, gnugrep
, writeShellScript, jq }:
let
  run-morpho-node = writeShellScript "morpho-node" ''
    set -exuo pipefail

    cd "$NOMAD_TASK_DIR"

    set +x
    echo "waiting for $REQUIRED_PEER_COUNT peers"
    until [ "$(cat "$NOMAD_TASK_DIR/morpho-topology.json" | jq '. | length')" -ge "$REQUIRED_PEER_COUNT" ]; do
      sleep 0.1
    done
    set -x

    exec morpho-checkpoint-node \
          --topology "$NOMAD_TASK_DIR"/morpho-topology.json \
          --database-path /local/db \
          --port "$NOMAD_PORT_morpho" \
          --config "$NOMAD_TASK_DIR"/morpho-config.yaml \
          --socket-dir "$NOMAD_TASK_DIR/socket" \
          "$@"
  '';
in {
  morpho = buildLayeredImage {
    name = "docker.mantis.ws/morpho-node";
    config = {
      Entrypoint = [ run-morpho-node ];
      Env = mkEnv {
        PATH = lib.makeBinPath [ coreutils gnugrep gnused morpho-node jq ];
      };
    };
  };
}
