{ dockerTools, telegraf }: {
  telegraf = dockerTools.buildLayeredImage {
    name = "docker.mantis.pw/telegraf";
    config.Entrypoint = [ "${telegraf}/bin/telegraf" ];
  };
}
