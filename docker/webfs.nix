{ lib, domain, mkEnv, buildLayeredImage, writeShellScript, webfs, coreutils
, mantis-explorer }:
let
  entrypoint = writeShellScript "webfs" ''
    set -exuo pipefail
    exec webfsd -F -j -p $NOMAD_PORT_http -r ${mantis-explorer} -f index.html
  '';
in {
  webfs = buildLayeredImage {
    name = "docker.${domain}/webfs";
    config = {
      Entrypoint = [ entrypoint ];
      Env = mkEnv { PATH = lib.makeBinPath [ coreutils webfs ]; };
    };
  };
}
