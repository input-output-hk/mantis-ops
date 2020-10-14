{ mkNomadJob, systemdSandbox, writeShellScript, telegraf }: {
  metrics = mkNomadJob "metrics" {
    datacenters = [ "eu-central-1" "us-east-2" ];
    taskGroups.metrics = {
      count = 1;

      services.metrics = { };

      tasks.metrics = systemdSandbox {
        name = "metrics";

        command = writeShellScript "telegraf" ''
          set -exuo pipefail

          exec ${telegraf}/bin/telegraf -config $NOMAD_TASK_DIR/telegraf.config
        '';

        templates = [{
          data = ''
            [agent]
            flush_interval = "10s"
            interval = "10s"
            omit_hostname = false

            [global_tags]
            role = "mantis"

            [inputs.prometheus]
            metric_version = 1
            urls = [
              {{ range services }}
                {{ if .Tags | contains "prometheus" }}
                  {{ range service .Name }}
                    "http://{{ .Address }}:{{ .Port }}?service={{ .Name }}&id={{ .ID }}",
                  {{ end }}
                {{ end }}
              {{ end }}
            ]

            [outputs.influxdb]
            database = "telegraf"
            urls = ["http://monitoring.node.consul:8428"]
          '';
          destination = "local/telegraf.config";
        }];
      };
    };
  };
}
