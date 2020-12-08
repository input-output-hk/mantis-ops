{ ... }: {
  services.grafana.provision.dashboards = [{
    name = "provisioned-mantis-ops";
    options.path = ../../../contrib/dashboards;
  }];
}
