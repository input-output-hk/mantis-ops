package jobs

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/mantis-ops/pkg/jobs/tasks:tasks"
	"list"
)

#Explorer: types.#stanza.job & {
	#args: {
		datacenters: list.MinItems(1)
		namespace:   string
		domain:      string
	}

	#domain:    #args.domain
	#name:      "\(namespace)-explorer"
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

	group: explorer: {
		service: "\(#name)": {
			address_mode: "host"
			port:         "explorer"
			tags: [namespace, #name, "ingress", "explorer"]
			meta: {
				PublicIp:      "${attr.unique.platform.aws.public-ipv4}"
				IngressHost:   #domain
				IngressMode:   "http"
				IngressBind:   "*:443"
				IngressServer: "_\(#name)._tcp.service.consul"
				IngressBackendExtra: """
					http-response set-header X-Server %s
					"""
			}

			check: explorer: {
				type:     "http"
				path:     "/"
				port:     "explorer"
				timeout:  "3s"
				interval: "30s"
				check_restart: {
					limit: 5
					grace: "300s"
				}
			}
		}

		network: {
			mode: "bridge"
			port: explorer: to: 8080
		}

		task: explorer: tasks.#Explorer & {
			#taskArgs: {
				upstreamServiceName: "\(namespace)-mantis-passive-rpc"
			}
		}
	}
}