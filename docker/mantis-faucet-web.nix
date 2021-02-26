{ lib, domain, mkEnv, dockerTools, buildLayeredImage, writeShellScript
, mantis-faucet-web, nginx, coreutils }:
let
  makeFaucet = extraAttrs: let
    web = mantis-faucet-web.overrideAttrs (old: extraAttrs);
    nginx-layered = buildLayeredImage {
      name = "docker.${domain}/nginx";
      contents = [ nginx web coreutils ];
    };
  in dockerTools.buildImage {
    name = "docker.${domain}/mantis-faucet-web";

    fromImage = nginx-layered;

    runAsRoot = writeShellScript "runAsRoot" ''
      ${dockerTools.shadowSetup}
      groupadd --system nginx
      useradd --system --gid nginx nginx
      mkdir -p /var/cache/nginx
      ln -s ${web} /mantis-faucet-web
    '';

    config = {
      Cmd = [ "nginx" ];
      ExposedPorts = { "8080/tcp" = { }; };
    };
  };
in
{
  mantis-faucet-web-evm = makeFaucet {
    MANTIS_VM = "EVM";
    FAUCET_NODE_URL = "https://faucet-evm.${domain}";
  };
  mantis-faucet-web-iele = makeFaucet {
    MANTIS_VM = "IELE";
    FAUCET_NODE_URL = "https://faucet-iele.${domain}";
  };
  mantis-faucet-web-kevm = makeFaucet {
    MANTIS_VM = "KEVM";
    FAUCET_NODE_URL = "https://faucet-kevm.${domain}";
  };
}
