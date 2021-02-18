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

  mantis-evm-base = dockerTools.pullImage {
    imageName = "inputoutput/mantis";
    imageDigest =
      "sha256:180d6873369693a9710e35118d4b76523955ccc0b1e6c96b1521e4a893876f23";
    sha256 = "sha256-ayW9C5sJxqvjLakFwUSDpthdDEgy6YX0eCcS0Rgu/tQ=";
    finalImageTag = "2020-evm";
    finalImageName = "inputoutput/mantis";
  };

  mantis-evm-deps = dockerTools.buildImage {
    name = "docker.${domain}/mantis-evm-deps";
    fromImage = mantis-evm-base;
    contents = debugUtils ++ [ awscli ];
  };
in {
  mantis-evm = dockerTools.buildImage {
    name = "docker.${domain}/mantis-evm";
    fromImage = mantis-evm-deps;
    config.Entrypoint = [ entrypoint ];
  };
}
