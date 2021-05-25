package jobs

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/mantis-ops/pkg/jobs/tasks:tasks"
)

#Mantis: types.#stanza.job & {
	#count:     uint | *5
	#role:      "passive" | "miner" | "backup"
	#logLevel:  string
	#mantisRev: string
	#fqdn:      string
	#loggers: {[string]: string}
	#network:       *"testnet-internal-nomad" | "etc"
	#networkConfig: string
	#fastSync:      bool

	let ref = {
		networkConfig: #networkConfig
		mantisRev:     #mantisRev
		role:          #role
		logLevel:      #logLevel
		loggers:       #loggers
		network:       #network
		fastSync:      #fastSync
	}

	namespace: string
	if #network == "etc" {
		type: "batch"
		periodic: {
			prohibit_overlap: true
			cron:             "@daily"
			time_zone:        "UTC"
		}
	}

	if #network != "etc" {
		type: "service"

		update: {
			max_parallel:      1
			health_check:      "checks"
			min_healthy_time:  "1m" // Give enough time for the DAG generation
			healthy_deadline:  "15m"
			progress_deadline: "30m"
			auto_revert:       false
			auto_promote:      false
			canary:            0
			stagger:           "20m"
		}
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

		if #network == "etc" {
			task: syncstat: tasks.#SyncStat
		}

		task: telegraf: tasks.#Telegraf & {
			#namespace:      namespace
			#name:           "\(#role)-${NOMAD_ALLOC_INDEX}"
			#prometheusPort: "metrics"
		}

		task: mantis: tasks.#Mantis & {
			#namespace:     namespace
			#mantisRev:     ref.mantisRev
			#role:          ref.role
			#logLevel:      ref.logLevel
			#networkConfig: ref.networkConfig
			#loggers:       ref.loggers
			#network:       ref.network
			#fastSync:      ref.fastSync
		}

		task: promtail: tasks.#Promtail

		#baseTags: [namespace, #role, "mantis-${NOMAD_ALLOC_INDEX}"]

		if #role == "passive" {
			service: "\(namespace)-mantis-\(#role)-rpc": {
				address_mode: "host"
				port:         "rpc"
				tags:         [
						"rpc",
						"ingress",
						"traefik.enable=true",
						"traefik.http.routers.\(namespace)-mantis-\(#role).rule=Host(`\(namespace)-\(#role).\(#fqdn)`)",
						"traefik.http.routers.\(namespace)-mantis-\(#role).entrypoints=https",
						"traefik.http.routers.\(namespace)-mantis-\(#role).tls=true",
				] + #baseTags
			}
		}

		if #role == "miner" {
			service: "\(namespace)-mantis-\(#role)-rpc": {
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
		}

		service: {
			"\(namespace)-mantis-\(#role)-prometheus": {
				address_mode: "host"
				port:         "metrics"
				tags:         ["prometheus"] + #baseTags
			}

			"\(namespace)-\(#role)-${NOMAD_ALLOC_INDEX}": {
				address_mode: "host"
				port:         "rpc"
				tags:         [
						"rpc",
						"ingress",
						"traefik.enable=true",
						"traefik.http.routers.\(namespace)-\(#role)-${NOMAD_ALLOC_INDEX}.rule=Host(`\(namespace)-\(#role)-${NOMAD_ALLOC_INDEX}.\(#fqdn)`)",
						"traefik.http.routers.\(namespace)-\(#role)-${NOMAD_ALLOC_INDEX}.entrypoints=https",
						"traefik.http.routers.\(namespace)-\(#role)-${NOMAD_ALLOC_INDEX}.tls=true",
				] + #baseTags
			}

			"\(namespace)-mantis-\(#role)-discovery-${NOMAD_ALLOC_INDEX}": {
				port: "discovery"

				if #role == "miner" {
					tags: ["ingress", "discovery",
						"traefik.enable=true",
						"traefik.tcp.routers.\(namespace)-discovery-${NOMAD_ALLOC_INDEX}.rule=HostSNI(`*`)",
						"traefik.tcp.routers.\(namespace)-discovery-${NOMAD_ALLOC_INDEX}.entrypoints=\(namespace)-discovery-${NOMAD_ALLOC_INDEX}",
					] + #baseTags
				}

				if #role == "passive" {
					tags: ["discovery"] + #baseTags
				}

				meta: {
					Name:     "mantis-${NOMAD_ALLOC_INDEX}"
					PublicIp: "${attr.unique.platform.aws.public-ipv4}"
				}
			}

			"\(namespace)-mantis-\(#role)-server-${NOMAD_ALLOC_INDEX}": {
				address_mode: "host"
				port:         "server"

				if #role == "miner" {
					tags: ["ingress", "server",
						"traefik.enable=true",
						"traefik.tcp.routers.\(namespace)-server-${NOMAD_ALLOC_INDEX}.rule=HostSNI(`*`)",
						"traefik.tcp.routers.\(namespace)-server-${NOMAD_ALLOC_INDEX}.entrypoints=\(namespace)-server-${NOMAD_ALLOC_INDEX}",
					] + #baseTags
				}

				if #role == "passive" {
					tags: ["server"] + #baseTags
				}

				meta: {
					Name:     "mantis-\(#role)-${NOMAD_ALLOC_INDEX}"
					PublicIp: "${attr.unique.platform.aws.public-ipv4}"
				}

				check: server: {
					address_mode: "host"
					interval:     "10s"
					port:         "server"
					timeout:      "3s"
					type:         "tcp"
					check_restart: {
						limit: 5
						grace: "10m"
					}
				}
			}

			"\(namespace)-mantis-\(#role)-server": {
				address_mode: "host"
				port:         "server"
				tags:         ["ingress", "server"] + #baseTags
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
