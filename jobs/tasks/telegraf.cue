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

	driver: "docker"

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	resources: {
		cpu:    100
		memory: 128
	}

	config: {
		image: #taskArgs.image.url
		args: ["-config", "/local/telegraf.config"]

		labels: [{
			namespace: #taskArgs.namespace
			name:      #taskArgs.name
			imageTag:  #taskArgs.image.tag
		}]

		logging: {
			type: "journald"
			config: [{
				tag:    "\(#taskArgs.name)-telegraf"
				labels: "name,namespace,imageTag"
			}]
		}
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
