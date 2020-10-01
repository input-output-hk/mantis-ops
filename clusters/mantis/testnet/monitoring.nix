{ ... }: {
  services.telegraf.extraConfig.inputs.prometheus.urls =
    [ "http://127.0.0.1:3101/metrics" "http://127.0.0.1:13798/" ];
}
