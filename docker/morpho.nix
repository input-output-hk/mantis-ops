{ lib, buildLayeredImage, mkEnv, morpho-node, coreutils, gnused, gnugrep, procps
, writeShellScript, jq, diffutils, huprestarter, bashInteractive, dnsutils }:
let

  node = writeShellScript "morpho-node" ''
    echo "Waiting for 10 seconds for topology to settle a bit more"
    # If the topology changes again during this time, this process is terminated and restarted by the huprestarter
    sleep 10

    cd "$NOMAD_TASK_DIR"
    if [[ -f running-morpho-topology.json ]]; then
      diff -u running-morpho-topology.json morpho-topology.json >/dev/stderr
    fi
    cp morpho-topology.json running-morpho-topology.json
    morpho-checkpoint-node \
      --topology "$NOMAD_TASK_DIR/morpho-topology.json" \
      --database-path /local/db \
      --port "$NOMAD_PORT_morpho" \
      --config "$NOMAD_TASK_DIR/morpho-config.yaml" \
      --socket-dir "$NOMAD_TASK_DIR/socket" \
      "$@"

    code=$?
    echo "morpho-checkpoint-node exited with code $code, sleeping for 10 seconds before restarting"
    sleep 10
    exit "$code"
  '';

  entrypoint = writeShellScript "morpho-entrypoint" ''
    # exec so that huprestarter becomes the main process, therefore receiving signals sent from nomad
    exec huprestarter --loop ${node}
  '';
in {
  morpho = buildLayeredImage {
    name = "docker.mantis.ws/morpho-node";
    config = {
      Entrypoint = [ entrypoint ];
      Env = mkEnv {
        PATH = lib.makeBinPath [
          coreutils
          gnugrep
          gnused
          morpho-node
          jq
          procps
          diffutils
          huprestarter

          # Debugging utils
          bashInteractive
          dnsutils
        ];
      };
    };
  };
}
