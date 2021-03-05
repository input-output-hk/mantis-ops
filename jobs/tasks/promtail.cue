package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
)

#Promtail: types.#stanza.task & {
	#taskArgs: {
		namespace: string
		name:      string
	}

	driver: "exec"

	config: {
		flake:   "github:NixOS/nixpkgs/nixpkgs-unstable#grafana-loki"
		command: "/bin/promtail"
		args: ["-config.file", "local/config.yaml"]
	}

	template: "local/config.yaml": {
		data: """
    server:
      http_listen_port: 0
      grpc_listen_port: 0

    positions:
      filename: /local/positions.yaml

    client:
      url: http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:3100/loki/api/v1/push

    scrape_configs:
     - job_name: \(#taskArgs.name)
       pipeline_stages:
       static_configs:
       - labels:
          syslog_identifier: \(#taskArgs.name)
          namespace: \(#taskArgs.namespace)
          dc: {{ env "NOMAD_DC" }}
          host: {{ env "HOSTNAME" }}
          __path__: /alloc/logs/*.std*.0
  """
	}
}
