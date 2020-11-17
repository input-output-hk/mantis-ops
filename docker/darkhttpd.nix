{ lib, mkEnv, buildLayeredImage, writeShellScript, darkhttpd, mime-types
, mantis-explorer }:
let
  entrypoint = writeShellScript "darkhttpd" ''
    set -exuo pipefail
    exec darkhttpd ${mantis-explorer} --port $NOMAD_PORT_http --no-server-id --mimetypes ${mime-types}/etc/mime.types
  '';
in {
  darkhttpd = buildLayeredImage {
    name = "docker.mantis.ws/darkhttpd";
    config = {
      Entrypoint = [ entrypoint ];
      Env = mkEnv { PATH = lib.makeBinPath [ darkhttpd ]; };
    };
  };
}
