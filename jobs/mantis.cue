package jobs

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/mantis-ops/pkg/jobs/tasks:tasks"
)

#Mantis: types.#stanza.job & {
	#args: {
		namespace: string
		count:     uint
		role:      "passive" | "miner" | "backup"
		mantisRev: string
		datacenters: [...string]
		images: [string]: {
			name: string
			tag:  string
			url:  string
		}
	}

	datacenters: #args.datacenters
	namespace:   #args.namespace
	type:        "service"

	#count: #args.count
	#role:  #args.role

	update: {
		max_parallel:      2
		health_check:      "checks"
		min_healthy_time:  "10s"
		healthy_deadline:  "5m"
		progress_deadline: "6m"
		auto_revert:       true
		auto_promote:      true
		canary:            1
		stagger:           "15m"
	}

	group: mantis: {
		count: #count
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

		reschedule: {
			attempts:  0
			unlimited: true
		}

		task: telegraf: tasks.#Telegraf & {
			#taskArgs: {
				namespace:      #args.namespace
				name:           "\(#role)-${NOMAD_ALLOC_INDEX}"
				prometheusPort: "metrics"
			}
		}

		task: mantis: tasks.#Mantis & {
			#taskArgs: {
				namespace: #args.namespace
				mantisRev: #args.mantisRev
				role:      #role
			}
		}

		task: promtail: tasks.#Promtail

		let baseTags = [namespace, #role]

		#baseTags: baseTags
		if #role == "passive" {
			service: "\(namespace)-mantis-\(#role)-rpc": {
				address_mode: "host"
				tags:         ["rpc"] + baseTags
				port:         "rpc"
			}

			#baseTags: [ namespace, "passive"]
		}

		service: {
			"\(namespace)-mantis-\(#role)-prometheus": {
				address_mode: "host"
				port:         "metrics"
				tags:         ["prometheus"] + #baseTags
			}

			"\(namespace)-mantis-\(#role)-rpc": {
				address_mode: "host"
				port:         "rpc"
				tags:         ["rpc"] + #baseTags

				check: rpc: {
					// needs https://github.com/hashicorp/nomad/issues/10084
					// type: "http"
					// path: "/"
					// header: "Content-Type": ["application/json"]
					// body:     json.Marshal({jsonrpc: "2.0", method: "eth_chainId", params: [], id: 1})
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

			"\(namespace)-mantis-\(#role)-discovery": {
				port: "discovery"
				tags: ["discovery"] + #baseTags
				meta: {
					Name:     "mantis-${NOMAD_ALLOC_INDEX}"
					PublicIp: "${attr.unique.platform.aws.public-ipv4}"
				}
			}

			"\(namespace)-mantis-\(#role)-server": {
				address_mode: "host"
				port:         "server"
				tags:         ["server"] + #baseTags
				meta: {
					Name:     "mantis-${NOMAD_ALLOC_INDEX}"
					PublicIp: "${attr.unique.platform.aws.public-ipv4}"
				}
			}

			"\(namespace)-mantis-\(#role)": {
				address_mode: "host"
				port:         "server"
				tags:         ["server"] + #baseTags
				meta: {
					Name:     "mantis-${NOMAD_ALLOC_INDEX}"
					PublicIp: "${attr.unique.platform.aws.public-ipv4}"
				}
			}
		}
	}
}
