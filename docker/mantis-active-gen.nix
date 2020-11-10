{ lib, buildLayeredImage, writeShellScript, writeShellScriptBin
, mantis-automation, coreutils, gnused, gnugrep, mc, vim, bashInteractive
, htop, tree, lsof, utillinux, openjdk8_headless, tmux }:
let
  entrypoint = writeShellScript "wait" ''
    mkdir -p /tmp
    while true; do sleep 60; done
  '';

  active-gen = writeShellScriptBin "active-gen" ''
    ${openjdk8_headless}/jre/bin/java -jar ${mantis-automation}/share/java/active-gen-fat.jar "$@"
  '';
in {
  mantis-active-gen = buildLayeredImage {
    name = "docker.mantis.ws/mantis-active-gen";
    contents = [
      active-gen
      bashInteractive
      coreutils
      gnugrep
      gnused
      htop
      lsof
      mc
      openjdk8_headless
      tree
      tmux
      utillinux
      vim
    ];

    config.Entrypoint = [ entrypoint ];
  };
}
