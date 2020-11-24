{ lib, mkEnv, buildImage, buildLayeredImage, writeShellScript, mantis-explorer
, nginx, shadowSetup }: {
  mantis-explorer-server = let
    nginx-layered = buildLayeredImage {
      name = "docker.mantis.ws/nginx";
      contents = [ nginx mantis-explorer ];
    };
  in buildImage {
    name = "docker.mantis.ws/mantis-explorer-server";

    fromImage = nginx-layered;

    runAsRoot = writeShellScript "runAsRoot" ''
      ${shadowSetup}
      groupadd --system nginx
      useradd --system --gid nginx nginx
      mkdir -p /var/cache/nginx
      ln -s ${mantis-explorer} /mantis-explorer
    '';

    config = {
      Cmd = [ "nginx" ];
      ExposedPorts = { "8080/tcp" = { }; };
    };
  };
}
