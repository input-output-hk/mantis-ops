{ lib, domain, mkEnv, buildImage, pullImage, writeShellScript, mantis, coreutils
, gnused, gnugrep, curl, debugUtils, procps, diffutils }:
let
  entrypoint = writeShellScript "mantis" ''
    set -exuo pipefail

    mkdir -p /tmp
    mkdir -p "$NOMAD_TASK_DIR/mantis"
    cd "$NOMAD_TASK_DIR"
    name="java"

    set +x
    until [ "$(grep -c enode mantis.conf)" -ge "$REQUIRED_PEER_COUNT" ]; do
      sleep 1
    done
    set -x

    ulimit -c unlimited
    cp mantis.conf running.conf

    (
      while true; do
        while diff -u running.conf mantis.conf > /dev/stderr; do
          sleep 300
        done

        if ! diff -u running.conf mantis.conf > /dev/stderr; then
          cp mantis.conf running.conf
          pkill "$name" || true
        fi
      done
    ) &

    starts=0
    while true; do
      starts="$((starts+1))"
      echo "Start Number $starts" > /dev/stderr
      mantis "-Duser.home=$NOMAD_TASK_DIR" "$@" || true
      sleep 10
    done
  '';

  mantis-kevm-base = pullImage {
    imageName = "inputoutput/mantis";
    imageDigest =
      "sha256:5d4cc1522aec793e3cb008c99720bdedde80ef004a102315ee7f3a9450abda5a";
    sha256 = "sha256-al6HE7E6giVTMCI7nOw3mc85NPEgzc3GEohDvfJFVnA=";
    finalImageTag = "2020-kevm";
    finalImageName = "inputoutput/mantis";
  };
in {
  mantis-kevm = buildImage {
    name = "docker.${domain}/mantis-kevm";
    fromImage = mantis-kevm-base;
    contents = debugUtils ++ [ coreutils gnugrep gnused curl procps diffutils ];
    config.Entrypoint = [ entrypoint ];
  };
}

