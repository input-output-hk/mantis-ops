{ lib, which, mkEnv, dockerTools, findutils, writeShellScript, mantis, mantis-source, coreutils, gnused
, gnugrep, curl, debugUtils, procps, diffutils, restic }:
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

      set +e
      # cat running.conf | head -n2 | cut -d' ' -f2 | xargs cat > /dev/stderr
      # which mantis  > /dev/stderr
      # echo ${mantis} > /dev/stderr
      ls -la > /dev/stderr
      ln -sf ${mantis}/conf
      set -e
      cat running.conf > /dev/stderr
      mantis "-Duser.home=$NOMAD_TASK_DIR" "$@" || true
      sleep 10
    done
  '';
in {
  mantis = dockerTools.buildLayeredImage {
    name = "docker.mantis.pw/mantis";
    contents = debugUtils
      ++ [ which coreutils findutils gnugrep gnused mantis mantis-source curl procps diffutils restic ];
    config.Entrypoint = [ entrypoint ];
  };
}
