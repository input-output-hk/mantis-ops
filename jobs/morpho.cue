package jobs

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/mantis-ops/pkg/jobs/tasks:tasks"
	"list"
)

#Morpho: types.#stanza.job & {
	#args: {
		datacenters: list.MinItems(1)
		namespace:   string
		index:       uint
		count:       uint
		mantisRev:   string
		morphoRev:   string
		fqdn:        string
		network:     string
	}

	#name: "morpho-\(#args.index)"
	#id:   "\(namespace)-\(#name)"

	datacenters: #args.datacenters
	namespace:   #args.namespace
	type:        "service"

	update: {
		max_parallel:      1
		health_check:      "checks"
		min_healthy_time:  "30s"
		healthy_deadline:  "10m"
		progress_deadline: "20m"
		auto_revert:       false
		auto_promote:      false
		canary:            0
		stagger:           "1m"
	}

	group: morpho: {
		service: "\(namespace)-morpho-node": {
			port: "morpho"

			tags: ["morpho", namespace]
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
			mode: "bridge"
			// From https://github.com/input-output-hk/bitte/blob/33cb20fa1cd7c6e4d3bc75253fc166bf048b500c/profiles/docker.nix#L16
			dns: servers: [ "172.17.0.1"]
			port: {
				discovery: to:        6000
				metrics: to:          6100
				rpc: to:              6200
				server: to:           6300
				morpho: to:           6400
				morphoPrometheus: to: 6500
			}
		}

		task: morpho: tasks.#Morpho & {
			#taskArgs: {
				namespace: #args.namespace
				morphoRev: #args.morphoRev
			}
		}

		task: "telegraf-morpho": tasks.#Telegraf & {
			#taskArgs: {
				namespace:      #args.namespace
				name:           "morpho-${NOMAD_ALLOC_INDEX}"
				prometheusPort: "morphoPrometheus"
			}
		}

		task: promtail: tasks.#Promtail & {
			#taskArgs: {
				namespace: #args.namespace
				name:      "morpho-${NOMAD_ALLOC_INDEX}"
			}
		}

		task: mantis: tasks.#Mantis & {
			#taskArgs: {
				namespace: #args.namespace
				mantisRev: #args.mantisRev
				role:      "passive"
				network:   #args.network
			}
		}
	}
}
