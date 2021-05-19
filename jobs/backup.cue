package jobs

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/mantis-ops/pkg/jobs/tasks:tasks"
)

#Mantis: types.#stanza.job & {
	#mantisRev:     string
	#networkConfig: string

	let ref = {
		networkConfig: #networkConfig
		mantisRev:     #mantisRev
	}

	namespace: string
	type:      "batch"

	periodic: {
		cron:             "15 */1 * * * *"
		prohibit_overlap: true
		timeZone:         "UTC"
	}

	group: mantis: {
		count: 1
		network: {
			mode: "host"
			port: {
				discovery: {}
				metrics: {}
				rpc: {}
				server: {}
			}
		}

		ephemeral_disk: {
			size:    10 * 1000
			migrate: true
			sticky:  true
		}

		task: telegraf: tasks.#Telegraf & {
			#namespace:      namespace
			#name:           "\(#role)-${NOMAD_ALLOC_INDEX}"
			#prometheusPort: "metrics"
		}

		task: mantis: tasks.#Mantis & {
			#namespace:     namespace
			#mantisRev:     ref.mantisRev
			#networkConfig: ref.networkConfig
		}

		task: promtail: tasks.#Promtail

		#baseTags: [namespace, "backup", "mantis-${NOMAD_ALLOC_INDEX}"]

		service: "\(namespace)-backup": {
			address_mode: "host"
			port:         "rpc"
			tags:         ["rpc"] + #baseTags

			check: rpc: {
				address_mode: "host"
				interval:     "10s"
				port:         "rpc"
				timeout:      "3s"
				type:         "tcp"
				check_restart: {
					limit: 5
					grace: "10m"
				}
			}
		}
	}
}
