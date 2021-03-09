package jobs

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/mantis-ops/pkg/jobs/tasks:tasks"
	"list"
)

#Faucet: types.#stanza.job & {
	#args: {
		datacenters:  list.MinItems(1)
		namespace:    string
		domain:       string
		wallet:       string | *"mantis-1"
		mantisOpsRev: string
	}

	#name:      "\(namespace)-faucet"
	#domain:    #args.domain
	#namespace: #args.namespace

	datacenters: #args.datacenters
	namespace:   #args.namespace
	type:        "service"

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
			task:         "nginx"
			tags: ["ingress", "faucet", namespace, #name]

			meta: {
				Name:          #name
				PublicIp:      "${attr.unique.platform.aws.public-ipv4}"
				IngressHost:   #domain
				IngressBind:   "*:443"
				IngressMode:   "http"
				IngressServer: "_\(#name)._tcp.service.consul"
				IngressBackendExtra: """
					option forwardfor
					http-response set-header X-Server %s
					"""
				IngressFrontendExtra: """
					reqidel ^X-Forwarded-For:.*
					"""
			}

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
			tags: ["ingress", "faucet", namespace, #name]
			meta: {
				Name:          #name
				PublicIp:      "${attr.unique.platform.aws.public-ipv4}"
				Wallet:        #args.wallet
				IngressHost:   "\(#name)-web.mantis.ws"
				IngressBind:   "*:443"
				IngressMode:   "http"
				IngressServer: "_\(#name)-web._tcp.service.consul"
			}
		}

		service: "\(#name)-rpc": {
			address_mode: "host"
			port:         "rpc"
			task:         "mantis"
			tags: ["ingress", "faucet", namespace, #name]
		}

		task: nginx: tasks.#FaucetNginx & {
			#taskArgs: {
				mantisOpsRev:        #args.mantisOpsRev
				upstreamServiceName: "\(#name)-rpc"
			}
		}

		task: mantis: tasks.#FaucetServer & {
			#taskArgs: {
				mantisOpsRev: #args.mantisOpsRev
				namespace:    #args.namespace
				wallet:       #args.wallet
			}
		}

		task: promtail: tasks.#Promtail

		task: telegraf: tasks.#Telegraf & {
			#taskArgs: {
				namespace:      #args.namespace
				name:           "faucet"
				prometheusPort: "metrics"
			}
		}
	}
}
