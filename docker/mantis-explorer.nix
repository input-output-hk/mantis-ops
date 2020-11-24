{ lib, mkEnv, buildLayeredImage, writeShellScript, mantis-explorer
, mantis-explorer-server }:
let
  entrypoint = writeShellScript "mantis-explorer-server" ''
    set -exuo pipefail

    exec mantis-explorer-server \
      --root ${mantis-explorer} \
      --port "$NOMAD_PORT_http" \
      --host 0.0.0.0
  '';
in {
  mantis-explorer-server = buildLayeredImage {
    name = "docker.mantis.ws/mantis-explorer-server";
    config = {
      Entrypoint = [ entrypoint ];
      Env = mkEnv { PATH = lib.makeBinPath [ mantis-explorer-server ]; };
    };
  };
}
