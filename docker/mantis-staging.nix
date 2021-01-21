{ lib, mkEnv, dockerTools, writeShellScript, mantis-staging, coreutils
, gnused, gnugrep, curl, debugUtils, procps, diffutils, restic }:
let
  entrypoint = writeShellScript "mantis" ''
    set -exuo pipefail

    mkdir -p /tmp
    cd "$NOMAD_TASK_DIR"
    name="java"

    if [ -d "$STORAGE_DIR" ]; then
      echo "$STORAGE_DIR found, not restoring from backup..."
    else
      echo "$STORAGE_DIR not found, restoring backup..."
      restic restore latest \
        --tag "$NAMESPACE" \
        --target / \
      || echo "couldn't restore backup, continue startup procedure..."
      mkdir -p "$NOMAD_TASK_DIR/mantis"
      rm -rf "$NOMAD_TASK_DIR/mantis/{keystore,node.key}"
      rm -rf "$NOMAD_TASK_DIR/mantis/logs"
    fi

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
      cat running.conf > /dev/stderr
      mantis "-Duser.home=$NOMAD_TASK_DIR" "$@" || true
      sleep 10
    done
  '';
in {
  mantis-staging = dockerTools.buildLayeredImage {
    name = "docker.mantis.pw/mantis";
    contents = debugUtils ++ [
      coreutils
      gnugrep
      gnused
      mantis-staging
      curl
      procps
      diffutils
      restic
    ];
    config.Entrypoint = [ entrypoint ];
  };
}
