{ mkEnv, writeShellScript, buildLayeredImage, restic-backup, debugUtils, cacert
, restic }:
let
  entrypoint = writeShellScript "restic-backup" ''
    mkdir -p /tmp
    mkdir -p "$NOMAD_TASK_DIR/mantis"
    cd "$NOMAD_TASK_DIR"
    ulimit -c unlimited
    exec ${restic-backup}/bin/restic-backup "$@"
  '';
in {
  backup = buildLayeredImage {
    name = "docker.mantis.ws/backup";
    contents = [ restic cacert ] ++ debugUtils;
    config.Entrypoint = [ entrypoint ];
    config.Env = mkEnv { AWS_DEFAULT_REGION = "eu-central-1"; };
  };
}
