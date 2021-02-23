package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"list"
	"strings"
)

#Mantis: types.#stanza.task & {
	#taskArgs: {
		namespace: string
		role:      "passive" | "miner" | "backup"
		image: {
			name: string
			tag:  string
			url:  string
		}
	}

	#role: #taskArgs.role
	#miners: []
	#amountOfMorphoNodes: 5
	#requiredPeerCount:   len(#miners)
	#namespace:           #taskArgs.namespace

	driver: "docker"

	resources: {
		cpu:    500
		memory: 5 * 1024
	}

	driver: "docker"
	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	config: {
		image: #taskArgs.image.url
		args: ["-Dconfig.file=running.conf"]
		ports: ["rpc", "server", "metrics", "discovery"]
		labels: {
			namespace: #namespace
			name:      "mantis-\(#role)-${NOMAD_ALLOC_INDEX}"
			imageTag:  #taskArgs.image.tag
		}

		logging: {
			type: "journald"
			config: [{
				tag:    "mantis-\(#role)-${NOMAD_ALLOC_INDEX}"
				labels: "name,namespace,imageTag"
			}]
		}
	}

	restart: {
		interval: "30m"
		attempts: 10
		delay:    "1m"
		mode:     "fail"
	}

	env: {
		REQUIRED_PEER_COUNT: "\(#requiredPeerCount)"
		STORAGE_DIR:         "/local/mantis"
		NAMESPACE:           #namespace
	}

	template: "local/mantis.conf": {
		let checkpointRange = list.Range(1, #amountOfMorphoNodes, 1)
		let checkpointKeys = [ for n in checkpointRange {
			"""
			{{- with secret "kv/data/nomad-cluster/\(#namespace)/obft-node-\(n)/obft-public-key" -}}
			"{{- .Data.data.value -}}"
			{{- end -}}
			"""
		}]

		_extraConfig: string

		if #role == "miner" {
			_extraConfig: """
			mantis.consensus.mining-enabled = true
			"""
		}

		if #role == "passive" {
			_extraConfig: """
			mantis.consensus.mining-enabled = false
			"""
		}

		change_mode: "noop"
		splay:       "15m"
		data:        """
		include "/conf/testnet-internal-nomad.conf"

		logging.json-output = true
		logging.logs-file = "logs"

		mantis = {
			blockchains.network = "testnet-internal-nomad"
			blockchains.testnet-internal-nomad = {
				custom-genesis-file = "/local/genesis.json"
				ecip1098-block-number = 0
				ecip1097-block-number = 0
				allowed-miners = []

				bootstrap-nodes = [
					{{ range service "\(#namespace)-mantis-miner-server" -}}
						"enode://  {{- with secret (printf "kv/data/nomad-cluster/\(#namespace)/%s/enode-hash" .ServiceMeta.Name) -}}
							{{- .Data.data.value -}}
							{{- end -}}@{{ .Address }}:{{ .Port }}",
					{{ end -}}
				]

				checkpoint-public-keys = [
					\(strings.Join(checkpointKeys, ","))
				]
			}

			client-id = "mantis-\(#role)-{{env "NOMAD_ALLOC_INDEX"}}"
			datadir = "/local/mantis"
			ethash.ethash-dir = "/local/ethash"
			metrics.enabled = true
			metrics.port = {{ env "NOMAD_PORT_metrics" }}
			network.rpc.http.interface = "0.0.0.0"
			network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}
			network.server-address.port = {{ env "NOMAD_PORT_server" }}
		}

		\(_extraConfig)
	"""
	}

	template: "local/genesis.json": {
		change_mode: "restart"
		data:        """
			{{- with secret "kv/nomad-cluster/\(#namespace)/genesis" -}}
			{{.Data.data | toJSON }}
			{{- end -}}
		"""
	}
}
