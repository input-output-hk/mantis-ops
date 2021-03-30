{ lib, buildLayeredImage, mkEnv, morpho-node, coreutils, bashInteractive
, writeShellScript, iana-etc, runCommandNoCC }:
let
  run-morpho-node = writeShellScript "morpho-node" ''
    morpho-checkpoint-node \
      --config "$NOMAD_TASK_DIR/morpho-config.yaml" \
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
