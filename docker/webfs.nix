{ lib, mkEnv, dockerTools, writeShellScript, webfs, coreutils
, mantis-explorer }:
let
  entrypoint = writeShellScript "webfs" ''
    set -exuo pipefail
    exec webfsd -F -j -p $NOMAD_PORT_http -r ${mantis-explorer} -f index.html
  '';
in {
  webfs = dockerTools.buildLayeredImage {
    name = "docker.mantis.pw/webfs";
    config = {
      Entrypoint = [ entrypoint ];
      Env = mkEnv { PATH = lib.makeBinPath [ coreutils webfs ]; };
    };
  };
}
