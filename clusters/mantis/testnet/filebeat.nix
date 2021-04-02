{ config, pkgs, ... }:
let
  configFile = pkgs.writeText "filebeat.yaml" ''
    path:
      home: ${pkgs.filebeat}
      data: /var/lib/filebeat/data
      logs: /var/lib/filebeat/logs
    output.logstash:
      hosts: ["${config.cluster.instances.monitoring.privateIP}:3100"]
    filebeat.autodiscover:
      providers:
        - type: nomad
          host: 127.0.0.1
          hints.enabled: true
          hints.default_config:
            type: log
            paths:
              - /var/lib/nomad/alloc/''${data.meta.uuid}/alloc/logs/*stderr.[0-9]*
              - /var/lib/nomad/alloc/''${data.meta.uuid}/alloc/logs/*stdout.[0-9]*
  '';
in {
  systemd.services.filebeat = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    script = ''
      exec ${pkgs.filebeat}/bin/filebeat -c ${configFile}
    '';

    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
      StateDirectory = "filebeat";
      WorkingDirectory = "/var/lib/filebeat";
    };
  };
}
