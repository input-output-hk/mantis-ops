{ lib, domain, buildLayeredImage, mkEnv, morpho-node, coreutils, gnused, gnugrep
, procps, writeShellScript, jq, diffutils }:
let
  run-morpho-node = writeShellScript "morpho-node" ''
    set -exuo pipefail

    cd "$NOMAD_TASK_DIR"
    name="morpho-checkpoint-node"

    cp morpho-topology.json running-morpho-topology.json

    (
      while true; do
        while diff -u running-morpho-topology.json morpho-topology.json > /dev/stderr; do
          sleep 300
        done

        if ! diff -u running-morpho-topology.json morpho-topology.json > /dev/stderr; then
          cp morpho-topology.json running-morpho-topology.json
          pkill "$name" || true
        fi
      done
    ) &

    starts=0
    while true; do
      starts="$((starts+1))"
      echo "Start Number $starts" > /dev/stderr
      morpho-checkpoint-node \
        --topology "$NOMAD_TASK_DIR/running-morpho-topology.json" \
        --database-path /local/db \
        --port "$NOMAD_PORT_morpho" \
        --config "$NOMAD_TASK_DIR/morpho-config.yaml" \
        --socket-dir "$NOMAD_TASK_DIR/socket" \
        "$@" || true
      sleep 10
    done
  '';
in {
  morpho = buildLayeredImage {
    name = "docker.${domain}/morpho-node";
    config = {
      Entrypoint = [ run-morpho-node ];
      Env = mkEnv {
        PATH = lib.makeBinPath [
          coreutils
          gnugrep
          gnused
          morpho-node
          jq
          procps
          diffutils
        ];
      };
    };
  };
}
