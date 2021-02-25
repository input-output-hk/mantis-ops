package jobs

import "github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"

#Explorer: types.#stanza.job & {
	#args: {
		datacenters: [...string]
		namespace: string
		domain:    string
		images: [string]: {
			name: string
			tag:  string
			url:  string
		}
	}

	#images:    #args.images
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

		task: explorer: {
			driver: "docker"

			config: {
				image: #images["mantis-explorer-server"].url
				args: ["nginx", "-c", "/local/nginx.conf"]
				ports: ["explorer"]

				labels: [{
					namespace: #namespace
					name:      #name
					imageTag:  #images["mantis-explorer-server"].tag
				}]

				logging: {
					type: "journald"
					config: [{
						tag:    #name
						labels: "name,namespace,imageTag"
					}]
				}
			}

			template: "local/nginx.conf": {
				change_mode: "restart"
				data:        """
					user nginx nginx;
					error_log /dev/stderr info;
					pid /dev/null;
					events {}
					daemon off;

					http {
						access_log /dev/stdout;

						upstream	backend	{
							least_conn;
							{{	range	service	"\(namespace)-mantis-passive-rpc"	}}
								server	{{	.Address	}}:{{	.Port	}};
							{{	end	}}
						}

						server	{
							listen	8080;

							location	/	{
								root	/mantis-explorer;
								index	index.html;
								try_files	$uri	$uri/	/index.html;
							}

							location	/rpc/node	{
								proxy_pass	http://backend/;
							}

							location	/sockjs-node	{
								proxy_pass	http://backend/;
							}
						}
					}
				"""
			}
		}
	}
}
