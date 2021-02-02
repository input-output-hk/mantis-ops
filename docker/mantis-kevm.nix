{ lib, domain, mkEnv, dockerTools, writeShellScript, debugUtils, awscli }:
let
  entrypoint = writeShellScript "mantis" ''
    set -exuo pipefail

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

  mantis-kevm-base = dockerTools.pullImage {
    imageName = "inputoutput/mantis";
    imageDigest =
      "sha256:5d4cc1522aec793e3cb008c99720bdedde80ef004a102315ee7f3a9450abda5a";
    sha256 = "sha256-al6HE7E6giVTMCI7nOw3mc85NPEgzc3GEohDvfJFVnA=";
    finalImageTag = "2020-kevm";
    finalImageName = "inputoutput/mantis";
  };

  mantis-kevm-deps = dockerTools.buildImage {
    name = "docker.${domain}/mantis-kevm-deps";
    fromImage = mantis-kevm-base;
    contents = debugUtils ++ [ awscli ];
  };
in {
  mantis-kevm = dockerTools.buildImage {
    name = "docker.${domain}/mantis-kevm";
    fromImage = mantis-kevm-deps;
    config.Entrypoint = [ entrypoint ];
  };
}
