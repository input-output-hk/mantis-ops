package jobs

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/mantis-ops/pkg/jobs/tasks:tasks"
)

#MantisE2E: types.#stanza.job & {
	#role:      "passive" | "miner" | "backup"
	#logLevel:  string
	#mantisRev: string
	#fqdn:      string
	#loggers: {[string]: string}
	#network:       *"testnet-internal-nomad" | "etc"
	#networkConfig: string

	#fastSync:   bool | *false
	#reschedule: {[string]: string | int | bool} | *{
		attempts:  0
		unlimited: true
	}

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

	let #groupTemplate = {
		#cpu:   int
		#index: string
		count:  1
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

		if #network == "etc" {
			restart: {
				interval: "1m"
				attempts: 0
				delay:    "1m"
				mode:     "fail"
			}
			task: syncstat: tasks.#SyncStat
		}

		reschedule: #reschedule

		task: telegraf: tasks.#Telegraf & {
			#namespace:      namespace
			#clientId:       "\(#role)-\(#index)"
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
			#minerCpu:      #cpu
			#peerCount:     #index
		}

		task: promtail: tasks.#Promtail

		#baseTags: [namespace, #role, "${NOMAD_GROUP_NAME}"]

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
					address_mode: "host"
					interval:     "10s"
					port:         "rpc"
					timeout:      "3s"
					type:         "http"
					path:         "/healthcheck"
					if #network != "etc" {
						check_restart: {
							limit: 5
							grace: "10m"
						}
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

			"\(namespace)-\(#role)-\(#index)": {
				address_mode: "host"
				port:         "rpc"
				tags:         [
						"rpc",
						"ingress",
						"traefik.enable=true",
						"traefik.http.routers.\(namespace)-\(#role)-\(#index).rule=Host(`\(namespace)-\(#role)-\(#index).\(#fqdn)`)",
						"traefik.http.routers.\(namespace)-\(#role)-\(#index).entrypoints=https",
						"traefik.http.routers.\(namespace)-\(#role)-\(#index).tls=true",
				] + #baseTags
			}

			"\(namespace)-mantis-\(#role)-discovery-\(#index)": {
				port: "discovery"

				if #role == "miner" {
					tags: ["ingress", "discovery",
						"traefik.enable=true",
						"traefik.tcp.routers.\(namespace)-discovery-\(#index).rule=HostSNI(`*`)",
						"traefik.tcp.routers.\(namespace)-discovery-\(#index).entrypoints=\(namespace)-discovery-\(#index)",
					] + #baseTags
				}

				if #role == "passive" {
					tags: ["discovery"] + #baseTags
				}

				meta: {
					Name:     "${NOMAD_GROUP_NAME}"
					PublicIp: "${attr.unique.platform.aws.public-ipv4}"
				}
			}

			"\(namespace)-mantis-\(#role)-server-\(#index)": {
				address_mode: "host"
				port:         "server"

				if #role == "miner" {
					tags: ["ingress", "server",
						"traefik.enable=true",
						"traefik.tcp.routers.\(namespace)-server-\(#index).rule=HostSNI(`*`)",
						"traefik.tcp.routers.\(namespace)-server-\(#index).entrypoints=\(namespace)-server-\(#index)",
					] + #baseTags
				}

				if #role == "passive" {
					tags: ["server"] + #baseTags
				}

				meta: {
					Name:     "mantis-\(#role)-\(#index)"
					PublicIp: "${attr.unique.platform.aws.public-ipv4}"
				}

				check: server: {
					address_mode: "host"
					interval:     "10s"
					port:         "server"
					timeout:      "3s"
					type:         "tcp"
					if #network != "etc" {
						check_restart: {
							limit: 5
							grace: "10m"
						}
					}
				}
			}

			"\(namespace)-mantis-\(#role)-server": {
				address_mode: "host"
				port:         "server"
				tags:         ["ingress", "server"] + #baseTags
				meta: {
					Name:     "${NOMAD_GROUP_NAME}"
					PublicIp: "${attr.unique.platform.aws.public-ipv4}"
				}
			}

			"\(namespace)-mantis-\(#role)": {
				address_mode: "host"
				port:         "server"
				tags:         ["server"] + #baseTags
				meta: {
					Name:     "${NOMAD_GROUP_NAME}"
					PublicIp: "${attr.unique.platform.aws.public-ipv4}"
				}
			}
		}
	}
	group: "mantis-4": #groupTemplate & {#index: "4"}
	group: "mantis-3": #groupTemplate & {#index: "3"}
	group: "mantis-2": #groupTemplate & {#cpu:   1000, #index: "2"}
	group: "mantis-1": #groupTemplate & {#cpu:   1000, #index: "1"}
	group: "mantis-0": #groupTemplate & {#cpu:   1000, #index: "0"}
}
