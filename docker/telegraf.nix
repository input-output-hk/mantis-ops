{ buildLayeredImage, telegraf }: {
  telegraf = buildLayeredImage {
    name = "docker.mantis.ws/telegraf";
    config.Entrypoint = [ "${telegraf}/bin/telegraf" ];
  };
}
