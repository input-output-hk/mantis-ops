{ lib, mkEnv, buildImage, buildLayeredImage, writeShellScript, mantis-faucet-web
, nginx, shadowSetup, coreutils }:
{
  mantis-faucet-web = let
    nginx-layered = buildLayeredImage {
      name = "docker.mantis.ws/nginx";
      contents = [ nginx mantis-faucet-web coreutils ];
    };
  in buildImage {
    name = "docker.mantis.ws/mantis-faucet-web";

    fromImage = nginx-layered;

    runAsRoot = writeShellScript "runAsRoot" ''
      ${shadowSetup}
      groupadd --system nginx
      useradd --system --gid nginx nginx
      mkdir -p /var/cache/nginx
      ln -s ${mantis-faucet-web} /mantis-faucet-web
    '';

    config = {
      Cmd = [ "nginx" ];
      ExposedPorts = { "8080/tcp" = { }; };
    };
  };
}
