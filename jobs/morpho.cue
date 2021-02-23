package jobs

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/mantis-ops/pkg/jobs/tasks:tasks"
	"list"
	encjson "encoding/json"
)

#Morpho: types.#stanza.job & {
	#args: {
		datacenters: [...string]
		namespace: string
		index:     uint
		count:     uint
		images: [string]: {
			name: string
			tag:  string
			url:  string
		}
	}

	#name:             "morpho-\(#args.index)"
	#id:               "\(namespace)-\(#name)"
	#nbNodes:          5
	#requiredMajority: (#nbNodes / 2) + 1

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

		task: morpho: {
			driver: "docker"

			vault: {
				policies: ["nomad-cluster"]
				change_mode: "noop"
			}

			resources: {
				cpu:    100
				memory: 1024
			}

			config: {
				image: #args.images.morpho.url
				args: []

				labels: {
					namespace: #args.namespace
					name:      "morpho-${NOMAD_ALLOC_INDEX}"
					imageTag:  #args.images.morpho.tag
				}

				logging: {
					type: "journald"
					config: [{
						tag:    "morpho-${NOMAD_ALLOC_INDEX}"
						labels: "name,namespace,imageTag"
					}]
				}
			}

			restart_policy: {
				interval: "10m"
				attempts: 10
				delay:    "30s"
				mode:     "delay"
			}

			template: "local/morpho-topology.json": {
				let range = list.Range(1, #nbNodes, 1)
				let addressFor = {
					#n:      uint
					addr:    "_\(namespace)-morpho-node._obft-node-\(#n).service.consul."
					valency: 1
				}
				let map = [ for n in range {
					nodeId: n
					producers: [ for p in range if p != n {addressFor & {#n: p}}]
				}]
				data: encjson.Marshal(map)
			}

			template: "secrets/morpho-private-key": {
				data: """
				{{- with secret "kv/data/nomad-cluster/${namespace}/${name}/obft-secret-key" -}}
				{{- .Data.data.value -}}
				{{- end -}}
				"""
				change_mode: "restart"
				splay:       "15m"
			}

			template: "local/morpho-config.yaml": {
				change_mode: "noop"
				splay:       "15m"
				data:        """
				ApplicationName: morpho-checkpoint
				ApplicationVersion: 1
				CheckpointInterval: 4
				FedPubKeys: [
				{{ range secrets "kv/metadata/nomad-cluster/\(namespace)/" -}}
					{{- if . | contains "obft" -}}
							"{{- with secret (printf "kv/data/nomad-cluster/\(namespace)/%s/obft-public-key" . ) -}}{{ .Data.data.value }}{{end}}",
					{{ end }}
				{{- end -}}
				]
				LastKnownBlockVersion-Major: 0
				LastKnownBlockVersion-Minor: 2
				LastKnownBlockVersion-Alt: 0
				NetworkMagic: 12345
				NodeId: {{env "NOMAD_ALLOC_INDEX"}}
				NodePrivKeyFile: {{ env "NOMAD_SECRETS_DIR" }}/morpho-private-key
				NumCoreNodes: \(#nbNodes)
				PoWBlockFetchInterval: 5000000
				PoWNodeRpcUrl: http://127.0.0.1:{{ env "NOMAD_PORT_rpc" }}
				PrometheusPort: {{ env "NOMAD_PORT_morphoPrometheus" }}
				Protocol: MockedBFT
				RequiredMajority: \(#requiredMajority)
				RequiresNetworkMagic: RequiresMagic
				SecurityParam: 2200
				StableLedgerDepth: 6
				SlotDuration: 5
				SnapshotsOnDisk: 60
				SnapshotInterval: 60
				SystemStart: "2020-11-17T00:00:00Z"
				TurnOnLogMetrics: True
				TurnOnLogging: True
				ViewMode: SimpleView
				minSeverity: Debug
				TracingVerbosity: NormalVerbosity
				setupScribes:
					- scKind: StdoutSK
						scFormat: ScText
						scName: stdout
				defaultScribes:
					- - StdoutSK
						- stdout
				setupBackends:
					- KatipBK
				defaultBackends:
					- KatipBK
				options:
					mapBackends:
				"""
			}
		}

		task: "telegraf-morpho": tasks.#Telegraf & {
			#taskArgs: {
				namespace:      #args.namespace
				name:           "morpho-${NOMAD_ALLOC_INDEX}"
				image:          #args.images["telegraf"]
				prometheusPort: "morphoPrometheus"
			}
		}
	}
}
