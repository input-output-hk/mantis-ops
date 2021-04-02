{ writeBashBinChecked, symlinkJoin, morpho-node, iana-etc, bashInteractive
, coreutils }:
let
  entrypoint = writeBashBinChecked "morpho-node-entrypoint" ''
    set -exuo pipefail

    exec ${morpho-node}/bin/morpho-checkpoint-node \
      --topology "$NOMAD_TASK_DIR/morpho-topology.json" \
      --database-path /local/db \
      --port "''${NOMAD_PORT_morpho:?}" \
      --config "$NOMAD_TASK_DIR/morpho-config.yaml" \
      --socket-dir "$NOMAD_TASK_DIR/socket" \
      "$@"
  '';
in symlinkJoin {
  paths = [ entrypoint morpho-node iana-etc bashInteractive coreutils ];
  name = "morpho-node";
}
