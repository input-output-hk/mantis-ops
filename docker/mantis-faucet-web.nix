{ lib, domain, mkEnv, dockerTools, buildLayeredImage, writeShellScript
, mantis-faucet-web, nginx, coreutils }: {
  mantis-faucet-web = let
    nginx-layered = buildLayeredImage {
      name = "docker.${domain}/nginx";
      contents = [ nginx mantis-faucet-web coreutils ];
    };
  in dockerTools.buildImage {
    name = "docker.${domain}/mantis-faucet-web";

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
