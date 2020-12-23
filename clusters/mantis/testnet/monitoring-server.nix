{ ... }: {
  services.grafana.provision.dashboards = [{
    name = "provisioned-mantis-ops";
    options.path = ../../../contrib/dashboards;
  }];
  services.loki.configuration.table_manager = {
    retention_deletes_enabled = true;
    retention_period = "28d";
  };
}
