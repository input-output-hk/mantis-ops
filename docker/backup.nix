{ mkEnv, domain, writeShellScript, pullImage, buildImage, restic-backup
, debugUtils, awscli, cacert, restic }:
let
  entrypoint = writeShellScript "restic-backup" ''
    mkdir -p /tmp
    mkdir -p "$NOMAD_TASK_DIR/mantis"
    cd "$NOMAD_TASK_DIR"
    ulimit -c unlimited
    exec ${restic-backup}/bin/restic-backup "$@"
  '';

  mantis-kevm-base = pullImage {
    imageName = "inputoutput/mantis";
    imageDigest =
      "sha256:5d4cc1522aec793e3cb008c99720bdedde80ef004a102315ee7f3a9450abda5a";
    sha256 = "sha256-al6HE7E6giVTMCI7nOw3mc85NPEgzc3GEohDvfJFVnA=";
    finalImageTag = "2020-kevm";
    finalImageName = "inputoutput/mantis";
  };

  mantis-kevm-deps = buildImage {
    name = "docker.${domain}/mantis-kevm-deps";
    fromImage = mantis-kevm-base;
    contents = debugUtils ++ [ awscli restic cacert ];
  };
in {
  backup = buildImage {
    name = "docker.${domain}/backup";
    fromImage = mantis-kevm-deps;
    config.Entrypoint = [ entrypoint ];
    config.Env = mkEnv {
      AWS_DEFAULT_REGION = "eu-central-1";
      PATH = "/bin";
    };
  };
}
