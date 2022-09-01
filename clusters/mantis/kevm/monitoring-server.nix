{ config, ... }: {
  services.grafana.provision.dashboards = [{
    name = "provisioned-mantis-ops";
    options.path = ../../../contrib/dashboards;
  }];

  services.loki.configuration.table_manager = {
    retention_deletes_enabled = true;
    retention_period = "14d";
  };

  services.ingress-config = {
    extraConfig = "";
    extraHttpsBackends = "";
  };

  systemd.services.victoriametrics.serviceConfig.LimitNOFILE = 65535;
}
