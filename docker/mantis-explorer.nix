{ lib, domain, mkEnv, dockerTools, buildLayeredImage, writeShellScript
, mantis-explorer, nginx }:
let
  makeExplorer = extraAttrs:
    let
      web = mantis-explorer.overrideAttrs (old: extraAttrs);
      nginx-layered = buildLayeredImage {
        name = "docker.${domain}/nginx";
        contents = [ nginx web ];
      };
    in dockerTools.buildImage {
      name = "docker.${domain}/mantis-explorer-server";

      fromImage = nginx-layered;

      runAsRoot = writeShellScript "runAsRoot" ''
        ${dockerTools.shadowSetup}
        groupadd --system nginx
        useradd --system --gid nginx nginx
        mkdir -p /var/cache/nginx
        ln -s ${web} /mantis-explorer
      '';

      config = {
        Cmd = [ "nginx" ];
        ExposedPorts = { "8080/tcp" = { }; };
      };
    };
in {
  mantis-explorer-evm = makeExplorer { MANTIS_VM = "EVM"; };
  mantis-explorer-iele = makeExplorer { MANTIS_VM = "IELE"; };
  mantis-explorer-kevm = makeExplorer { MANTIS_VM = "KEVM"; };
}
