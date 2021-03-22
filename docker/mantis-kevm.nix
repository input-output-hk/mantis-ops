{ lib, domain, mkEnv, dockerTools, writeShellScript, debugUtils, awscli
, mantis-kevm, kevm, diffutils, gnused, gawk, coreutils, gnugrep, procps }:
let
  entrypoint = writeShellScript "mantis" ''
    set -exuo pipefail

    export PATH="${
      lib.makeBinPath [
        diffutils
        coreutils
        mantis-kevm
        awscli
        gnugrep
        procps
        gnused
        gawk
      ]
    }"

    mkdir -p /tmp
    mkdir -p "$NOMAD_TASK_DIR/mantis"
    cd "$NOMAD_TASK_DIR"
    name="java"

    if [ -n "''${DAG_NAME:-}" ]; then
      if [ -f "ethash/$DAG_NAME" ]; then
        echo "found existing DAG"
        sha256sum "ethash/$DAG_NAME"
      else
        mkdir -p ethash
        aws \
          --endpoint-url "$MONITORING_ADDR" \
          s3 cp \
          "s3://mantis-kevm-dag/$DAG_NAME" \
          "ethash/$DAG_NAME" \
        || echo "Unable to download DAG, skipping."
      fi
    fi

    set +x
    until [ "$(grep -c enode mantis.conf)" -ge "$REQUIRED_PEER_COUNT" ]; do
      sleep 1
    done

    if [ -n "''${DAG_NAME:-}" ]; then
      delay="$((REQUIRED_PEER_COUNT * 100))"
      echo "waiting for $delay seconds before start"
      sleep "$delay"
    fi
    set -x

    ulimit -c unlimited
    cp mantis.conf running.conf

    (
      while true; do
        set +x
        while diff -u running.conf mantis.conf > /dev/stderr; do
          sleep 900
        done
        set -x

        if ! diff -u running.conf mantis.conf > /dev/stderr; then
          echo "Found updated config file, restarting Mantis"
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
  mantis-kevm = dockerTools.buildLayeredImage {
    name = "docker.${domain}/mantis-kevm";
    contents = debugUtils ++ [ mantis-kevm kevm ];
    config.Entrypoint = [ entrypoint ];
  };
}
