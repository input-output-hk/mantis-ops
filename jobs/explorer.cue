package jobs

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/mantis-ops/pkg/jobs/tasks:tasks"
)

#Explorer: types.#stanza.job & {
	#args: {
		datacenters: [...string]
		namespace: string
		domain:    string
	}

	#domain:    #args.domain
	#name:      "\(namespace)-explorer"
	#namespace: #args.namespace

	datacenters: #args.datacenters
	namespace:   #args.namespace
	type:        "service"

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
