{ buildLayeredImage, domain, telegraf }: {
  telegraf = buildLayeredImage {
    name = "docker.${domain}/telegraf";
    config.Entrypoint = [ "${telegraf}/bin/telegraf" ];
  };
}
