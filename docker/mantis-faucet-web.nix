{ lib, mkEnv, dockerTools, writeShellScript, mantis-faucet-web
, nginx, coreutils }: {
  mantis-faucet-web = let
    nginx-layered = dockerTools.buildLayeredImage {
      name = "docker.mantis.pw/nginx";
      contents = [ nginx mantis-faucet-web coreutils ];
    };
  in dockerTools.buildImage {
    name = "docker.mantis.pw/mantis-faucet-web";

    fromImage = nginx-layered;

    runAsRoot = writeShellScript "runAsRoot" ''
      ${dockerTools.shadowSetup}
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
