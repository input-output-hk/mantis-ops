{ lib, buildLayeredImage, mkEnv, morpho-node, coreutils, gnused, gnugrep, procps
, writeShellScript, jq }:
let
  run-morpho-node = writeShellScript "morpho-node" ''
    set -exuo pipefail

    cd "$NOMAD_TASK_DIR"
    name="morpho-checkpoint-node"

    restartCount=0

    function reload () {
      pkill "$name" || true

      count=0
      restartCount=0

      until ! pgrep -c "$name"; do
        count="$((count+1))"
        if [ "$count" -gt 60 ]; then
          pkill -9 "$name"
        fi
        sleep 1
      done
    }

    function report_quit() {
      code=$?
      echo exit $code happening > /dev/stderr
      exit $code
    }

    trap reload HUP
    trap report_quit EXIT

    while true; do
      echo "(re)starting at $(date)" >/dev/stderr
      morpho-checkpoint-node \
        --topology "$NOMAD_TASK_DIR"/morpho-topology.json \
        --database-path /local/db \
        --port "$NOMAD_PORT_morpho" \
        --config "$NOMAD_TASK_DIR"/morpho-config.yaml \
        --socket-dir "$NOMAD_TASK_DIR/socket" \
        "$@" &

      wait -n || true
      restartCount="$((restartCount+1))"

      sleep 1

      if [ "$((restartCount % 5))" -eq 0 ]; then
        pkill -9 "$name" || true
        rm -rf /local/db
      fi
    done
  '';
in {
  morpho = buildLayeredImage {
    name = "docker.mantis.ws/morpho-node";
    config = {
      Entrypoint = [ run-morpho-node ];
      Env = mkEnv {
        PATH =
          lib.makeBinPath [ coreutils gnugrep gnused morpho-node jq procps ];
      };
    };
  };
}
