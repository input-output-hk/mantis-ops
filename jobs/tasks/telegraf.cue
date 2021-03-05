package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
)

#Telegraf: types.#stanza.task & {
	#taskArgs: {
		namespace:      string
		name:           string
		prometheusPort: string
		image: {
			name: string
			tag:  string
			url:  string
		}
	}

	driver: "exec"

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	resources: {
		cpu:    100
		memory: 128
	}

	config: {
		flake:   "github:NixOS/nixpkgs/nixos-20.09#telegraf"
		command: "/bin/telegraf"
		args: ["-config", "/local/telegraf.config"]
	}

	template: "local/telegraf.config": {
		data: """
		[agent]
		flush_interval = "10s"
		interval = "10s"
		omit_hostname = false

		[global_tags]
		client_id = "\(#taskArgs.name)"
		namespace = "\(#taskArgs.namespace)"

		[inputs.prometheus]
		metric_version = 1

		urls = [ "http://{{ env "NOMAD_ADDR_\(#taskArgs.prometheusPort)" }}" ]

		[outputs.influxdb]
		database = "telegraf"
		urls = [ {{ with node "monitoring" }}"http://{{ .Node.Address }}:8428"{{ end }} ]
		"""
	}
}