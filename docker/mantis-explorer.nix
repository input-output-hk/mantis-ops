{ lib, domain, mkEnv, buildImage, buildLayeredImage, writeShellScript
, mantis-explorer, nginx, shadowSetup }: {
  mantis-explorer-server = let
    nginx-layered = buildLayeredImage {
      name = "docker.${domain}/nginx";
      contents = [ nginx mantis-explorer ];
    };
  in buildImage {
    name = "docker.${domain}/mantis-explorer-server";

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
