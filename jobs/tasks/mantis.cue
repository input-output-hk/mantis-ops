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
		mantisRev: string
		network:   string
	}

	#role: #taskArgs.role
	#miners: []
	#amountOfMorphoNodes: 5
	#requiredPeerCount:   len(#miners)
	#namespace:           #taskArgs.namespace

	driver: "exec"

	resources: {
		cpu:    7500
		memory: 5 * 1024
	}

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	config: {
		flake:   "github:input-output-hk/mantis?rev=\(#taskArgs.mantisRev)#mantis-entrypoint"
		command: "/bin/mantis-entrypoint"
		args: ["-Dconfig.file=/local/running.conf", "-XX:ActiveProcessorCount=2"]
	}

	restart: {
		interval: "30m"
		attempts: 10
		delay:    "1m"
		mode:     "fail"
	}

	env: {
		REQUIRED_PEER_COUNT: "${NOMAD_ALLOC_INDEX}"
		STORAGE_DIR:         "/local/mantis"
		NAMESPACE:           #namespace
		DAG_NAME:            "full-R23-0000000000000000"
		DAG_BUCKET:          "mantis-dag"
		MONITORING_ADDR:     "http://172.16.0.20:9000"
		AWS_DEFAULT_REGION:  "us-east-1"
	}

	#vaultPrefix: 'kv/data/nomad-cluster/\(#namespace)/mantis-%s'

	template: "secrets/secret-key": {
		#prefix:     'kv/data/nomad-cluster/\(#namespace)/mantis-%s'
		change_mode: "noop"
		splay:       "15m"
		data:        """
		{{ with secret (printf "\(#vaultPrefix)/secret-key" (env "NOMAD_ALLOC_INDEX")) }}{{.Data.data.value}}{{end}}
		{{ with secret (printf "\(#vaultPrefix)/enode-hash" (env "NOMAD_ALLOC_INDEX")) }}{{.Data.data.value}}{{end}}
		"""
	}

	template: "secrets/env.txt": {
		data: """
			AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
			AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
			"""
		env:         true
		change_mode: "noop"
	}

	template: "local/mantis.conf": {
		#checkpointRange: list.Range(1, #amountOfMorphoNodes, 1)
		#checkpointKeys: [ for n in #checkpointRange {
			"""
			{{- with secret "kv/data/nomad-cluster/\(#namespace)/obft-node-\(n)/obft-public-key" -}}
			"{{- .Data.data.value -}}"
			{{ end -}}
			"""
		}]
		#checkPointKeysString: strings.Join(#checkpointKeys, ",")

		#extraConfig: string

		if #role == "miner" {
			#extraConfig: """
			mantis = {
				node-key-file = "/secrets/secret-key"
				consensus = {
					mining-enabled = true
					coinbase = "{{ with secret (printf "\(#vaultPrefix)/coinbase" (env "NOMAD_ALLOC_INDEX")) }}{{.Data.data.value}}{{end}}"
				}
			}
			"""
		}

		if #role == "passive" {
			#extraConfig: """
				mantis.consensus.mining-enabled = false
				"""
		}

		#saganoConf: string

		if #taskArgs.network != "sagano" {
			#saganoConf: ""
		}

		if #taskArgs.network == "sagano" {
			#saganoConf: """
			blockchains.testnet-internal-nomad = {
				custom-genesis-file = "/local/genesis.json"
				allowed-miners = []

				bootstrap-nodes = [
					{{ range service "\(#namespace)-mantis-miner" -}}
						"enode://  {{- with secret (printf "kv/data/nomad-cluster/\(#namespace)/%s/enode-hash" .ServiceMeta.Name) -}}
							{{- .Data.data.value -}}
							{{- end -}}@{{ .Address }}:{{ .Port }}",
					{{ end -}}
				]

				checkpoint-public-keys = [
					\(#checkPointKeysString)
				]
			}
			"""
		}

		change_mode: "noop"
		splay:       "15m"
		data:        """
		include "/conf/base.conf"
		include "/conf/\(#taskArgs.network).conf"

		logging.json-output = false
		logging.logs-file = "logs"

		mantis = {
			\(#saganoConf)

			client-id = "mantis-\(#role)-{{env "NOMAD_ALLOC_INDEX"}}"
			datadir = "/local/mantis"
			ethash.ethash-dir = "/local/ethash"

			sync.do-fast-sync = false

			metrics.enabled = true
			metrics.port = {{ env "NOMAD_PORT_metrics" }}

			network.rpc.http.interface = "0.0.0.0"
			network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}

			network.server-address.port = {{ env "NOMAD_PORT_server" }}
			network.server-address.interface = "0.0.0.0"

			network.discovery.discovery-enabled = true
			network.discovery.host = "172.16.0.20"
			network.discovery.port = {{ env "NOMAD_PORT_discovery" }}
		}

		\(#extraConfig)
		"""
	}

	template: "local/genesis.json": {
		change_mode: "noop"
		data:        """
		{{- with secret "kv/nomad-cluster/\(#namespace)/genesis" -}}
		{{.Data.data | toJSON }}
		{{- end -}}
		"""
	}
}
