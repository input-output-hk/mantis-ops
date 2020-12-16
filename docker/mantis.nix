{ lib, domain, mkEnv, buildLayeredImage, writeShellScript, mantis, coreutils
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
in {
  mantis = buildLayeredImage {
    name = "docker.${domain}/mantis";
    contents = debugUtils
      ++ [ coreutils gnugrep gnused mantis curl procps diffutils ];
    config.Entrypoint = [ entrypoint ];
  };
}
