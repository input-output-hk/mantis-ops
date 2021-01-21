{ lib, mkEnv, dockerTools, writeShellScript, mantis-explorer
, nginx }: {
  mantis-explorer-server = let
    nginx-layered = dockerTools.buildLayeredImage {
      name = "docker.mantis.pw/nginx";
      contents = [ nginx mantis-explorer ];
    };
  in dockerTools.buildImage {
    name = "docker.mantis.pw/mantis-explorer-server";

    fromImage = nginx-layered;

    runAsRoot = writeShellScript "runAsRoot" ''
      ${dockerTools.shadowSetup}
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
