{ lib, mkEnv, buildLayeredImage, writeShellScript, mantis
, coreutils, gnused, gnugrep, curl, debugUtils, procps, diffutils }:
let
  entrypoint = writeShellScript "mantis" ''
    set -exuo pipefail

    mkdir -p /tmp
    mkdir -p "$NOMAD_TASK_DIR/mantis"
    cd "$NOMAD_TASK_DIR"
    name="java"

    ulimit -c unlimited

    restartCount=0

    function noop () {
      echo "redundant hup"
      diff -u running.conf mantis.conf > /dev/stderr || true
    }

    function reload () {
      trap noop HUP
      echo "reload requested" > /dev/stderr
      diff -u running.conf mantis.conf > /dev/stderr || true
      if pgrep -c "$name"; then
        echo "reloading in 300 seconds" > /dev/stderr
        sleep 300
      fi
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
      trap reload HUP
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
      diff -u running.conf mantis.conf > /dev/stderr || true
      cp mantis.conf running.conf
      mantis "-Duser.home=$NOMAD_TASK_DIR" "$@" &
      while ! wait; do
        true
      done
      restartCount="$((restartCount+1))"
      if [ "$((restartCount % 5))" -eq 0 ]; then
        pkill -9 "$name" || true
      fi
      sleep 1
    done
  '';
in {
  mantis = buildLayeredImage {
    name = "docker.mantis.ws/mantis";
    contents = debugUtils ++ [ coreutils gnugrep gnused mantis curl procps diffutils ];
    config.Entrypoint = [ entrypoint ];
  };
}
