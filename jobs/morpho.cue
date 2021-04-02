package jobs

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/mantis-ops/pkg/jobs/tasks:tasks"
)

#Morpho: types.#stanza.job & {
	#index:     uint
	#count:     uint
	#mantisRev: string
	#morphoRev: string
	#fqdn:      string
	#network:   string

	#name: "morpho-\(#index)"
	#id:   "\(namespace)-\(#name)"

	let ref = {morphoRev: #morphoRev, network: #network, mantisRev: #mantisRev}

	namespace: string
	type:      "service"

	update: {
		max_parallel:      2
		health_check:      "checks"
		min_healthy_time:  "10s"
		healthy_deadline:  "1m"
		progress_deadline: "2m"
		auto_revert:       false
		auto_promote:      false
		canary:            0
		stagger:           "30s"
	}

	group: morpho: {
		count: #count

		service: "\(namespace)-morpho-node": {
			address_mode: "host"
			port:         "morpho"

			tags: ["morpho", namespace, "obft-node-${NOMAD_ALLOC_INDEX}"]
			meta: {
				NodeNumber: "${NOMAD_ALLOC_INDEX}"
			}
		}

		ephemeral_disk: {
			size:    500
			migrate: true
			sticky:  true
		}

		network: {
			mode: "host"
			// From https://github.com/input-output-hk/bitte/blob/33cb20fa1cd7c6e4d3bc75253fc166bf048b500c/profiles/docker.nix#L16
			dns: servers: [ "172.17.0.1"]
			port: {
				discovery: {}
				metrics: {}
				rpc: {}
				server: {}
				morpho: {}
				morphoPrometheus: {}
			}
		}

		task: morpho: tasks.#Morpho & {
			#namespace: namespace
			#morphoRev: ref.morphoRev
		}

		task: "telegraf-morpho": tasks.#Telegraf & {
			#namespace:      namespace
			#name:           "morpho-${NOMAD_ALLOC_INDEX}"
			#prometheusPort: "morphoPrometheus"
		}

		task: promtail: tasks.#Promtail & {
			#namespace: namespace
			#name:      "morpho-${NOMAD_ALLOC_INDEX}"
		}

		task: mantis: tasks.#Mantis & {
			#namespace: namespace
			#mantisRev: ref.mantisRev
			#role:      "passive"
			#network:   ref.network
		}
	}
}
