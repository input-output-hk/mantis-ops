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
		images: [string]: [string]: string
		datacenters: [...string]
	}

	datacenters: #args.datacenters
	namespace:   #args.namespace
	type:        "service"

	#count: #args.count
	#role:  #args.role

	group: mantis: {
		count: #count
		network: {
			mode: "bridge"
			port: {
				discovery: to: 6000
				metrics: to:   7000
				rpc: to:       8000
				server: to:    9000
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
				image:          #args.images["telegraf"]
				prometheusPort: "metrics"
			}
		}

		task: mantis: tasks.#Mantis & {
			#taskArgs: {
				namespace: #args.namespace
				image:     #args.images["mantis"]
				role:      #role
			}
		}

		let baseTags = [namespace, #role]
		let discoveryMeta = {}
		let serverMeta = {}
		let baseMeta = {}

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
			}

			"\(namespace)-mantis-\(#role)-discovery": {
				port: "discovery"
				tags: ["discovery"] + #baseTags
				meta: {
					Name:     "mantis-${NOMAD_ALLOC_INDEX}"
					PublicIp: "${attr.unique.platform.aws.public-ipv4}"
				} & discoveryMeta
			}

			"\(namespace)-mantis-\(#role)-server": {
				port: "server"
				tags: ["server"] + #baseTags
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
