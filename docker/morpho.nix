{ lib, buildLayeredImage, mkEnv, morpho-node, coreutils, bashInteractive
, writeShellScript, iana-etc, runCommandNoCC }:
let
  run-morpho-node = writeShellScript "morpho-node" ''
    morpho-checkpoint-node \
      --topology "$NOMAD_TASK_DIR/morpho-topology.json" \
      --database-path /local/db \
      --port "$NOMAD_PORT_morpho" \
      --config "$NOMAD_TASK_DIR/morpho-config.yaml" \
      --socket-dir "$NOMAD_TASK_DIR/socket" \
      "$@"
  '';
  # Needed for DNS to work
  etcRoot = runCommandNoCC "etc" {} ''
    mkdir -p $out/etc
    ln -s ${iana-etc}/etc/services $out/etc/services
  '';
in {
  morpho = buildLayeredImage {
    name = "docker.mantis.ws/morpho-node";
    contents = [ etcRoot ];
    config = {
      Entrypoint = [ run-morpho-node ];
      Env = mkEnv {
        PATH = lib.makeBinPath [
          morpho-node

          bashInteractive
          coreutils
        ];
      };
    };
  };
}
