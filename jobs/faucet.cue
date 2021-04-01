package jobs

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/mantis-ops/pkg/jobs/tasks:tasks"
)

#Faucet: types.#stanza.job & {
	#fqdn:         string
	#wallet:       string | *"mantis-1"
	#mantisOpsRev: types.#gitRevision
	#network:      string
	#name:         "\(namespace)-faucet"

	let ref = {wallet: #wallet, mantisOpsRev: #mantisOpsRev}

	namespace: string
	type:      "service"

	update: {
		max_parallel:      1
		health_check:      "checks"
		min_healthy_time:  "10s"
		healthy_deadline:  "7m"
		progress_deadline: "10m"
		auto_revert:       true
		auto_promote:      true
		canary:            1
		stagger:           "5m"
	}

	group: faucet: {
		network: {
			mode: "host"
			port: {
				metrics: {}
				rpc: {}
				nginx: {}
				server: {}
			}
		}

		service: "\(#name)": {
			address_mode: "host"
			port:         "rpc"
			task:         "mantis"

			tags: ["ingress", "faucet", namespace, #name,
				"traefik.enable=true",
				"traefik.http.routers.\(namespace)-faucet-rpc.rule=Host(`\(#name).\(#fqdn)`)",
				"traefik.http.routers.\(namespace)-faucet-rpc.entrypoints=https",
				"traefik.http.routers.\(namespace)-faucet-rpc.tls=true",
				"traefik.http.routers.\(namespace)-faucet-rpc.middlewares=corsheader@consulcatalog",
				"traefik.http.middlewares.corsheader.headers.accesscontrolallowmethods=GET,OPTIONS,POST",
				"traefik.http.middlewares.corsheader.headers.accesscontrolalloworigin=*",
				"traefik.http.middlewares.corsheader.headers.accesscontrolmaxage=100",
				"traefik.http.middlewares.corsheader.headers.addvaryheader=true",
				"traefik.http.middlewares.corsheader.headers.accesscontrolallowheaders=Content-Type",
			]

			check: nginx: {
				type:     "http"
				path:     "/"
				port:     "nginx"
				timeout:  "3s"
				interval: "30s"
				check_restart: {
					limit: 0
					grace: "60s"
				}
			}
		}

		service: "\(#name)-web": {
			address_mode: "host"
			port:         "nginx"
			task:         "nginx"

			tags: ["ingress", "faucet", namespace, #name,
				"traefik.enable=true",
				"traefik.http.routers.\(namespace)-faucet-nginx.rule=Host(`\(#name)-web.\(#fqdn)`)",
				"traefik.http.routers.\(namespace)-faucet-nginx.entrypoints=https",
				"traefik.http.routers.\(namespace)-faucet-nginx.tls=true",
				"traefik.http.routers.\(namespace)-faucet-nginx.middlewares=corsheader@consulcatalog",
				"traefik.http.middlewares.corsheader.headers.accesscontrolallowmethods=GET,OPTIONS,POST",
				"traefik.http.middlewares.corsheader.headers.accesscontrolalloworigin=*",
				"traefik.http.middlewares.corsheader.headers.accesscontrolmaxage=100",
				"traefik.http.middlewares.corsheader.headers.addvaryheader=true",
				"traefik.http.middlewares.corsheader.headers.accesscontrolallowheaders=Content-Type",

			]

			meta: {
				Name:     #name
				PublicIp: "${attr.unique.platform.aws.public-ipv4}"
				Wallet:   #wallet
			}
		}

		service: "\(#name)-rpc": {
			address_mode: "host"
			port:         "rpc"
			task:         "mantis"
			tags: ["ingress", "faucet", namespace, #name]
		}

		task: nginx: tasks.#FaucetNginx & {
			#mantisOpsRev:        ref.mantisOpsRev
			#upstreamServiceName: "\(#name)-rpc"
		}

		task: mantis: tasks.#FaucetServer & {
			#mantisOpsRev: ref.mantisOpsRev
			#namespace:    namespace
			#wallet:       ref.wallet
		}

		task: promtail: tasks.#Promtail

		task: telegraf: tasks.#Telegraf & {
			#namespace:      namespace
			#name:           "faucet"
			#prometheusPort: "metrics"
		}
	}
}
