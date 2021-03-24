package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
)

#Mantis: types.#stanza.task & {
	#namespace: string
	#role:      "passive" | "miner" | "backup" | "faucet"
	#mantisRev: string
	#network:   string
	#flake:     types.#flake
	#miners: []
	#wallet:      =~"mantis-\\d+"
	#extraConfig: string | *""

	driver: "exec"

	resources: {cpu: uint, memory: uint}

	if #role == "miner" {
		resources: {
			cpu:    7500
			memory: 4 * 1024
		}
	}

	if #role == "passive" {
		resources: {
			cpu:    1000
			memory: 4 * 1024
		}
	}

	if #role == "faucet" {
		resources: {
			cpu:    1000
			memory: 5 * 1024
		}
	}

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	config: {
		flake:   #flake
		command: "/bin/mantis-entrypoint"
		if #role == "faucet" {
			args: [
				"-Dconfig.file=/local/running.conf",
				"-XX:ActiveProcessorCount=2",
				"-J-Xms512m",
				"-J-Xmx\(resources.memory)m",
				"faucet",
			]
		}
		if #role != "faucet" {
			args: [
				"-Dconfig.file=/local/running.conf",
				"-XX:ActiveProcessorCount=2",
				"-J-Xms512m",
				"-J-Xmx\(resources.memory)m",
			]
		}
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
		data:        """
		{{ with secret (printf "\(#vaultPrefix)/secret-key" (env "NOMAD_ALLOC_INDEX")) }}{{.Data.data.value}}{{end}}
		{{ with secret (printf "\(#vaultPrefix)/enode-hash" (env "NOMAD_ALLOC_INDEX")) }}{{.Data.data.value}}{{end}}
		"""
	}

	template: "secrets/env.txt": {
		env:         true
		change_mode: "noop"
		data: """
			AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
			AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
			"""
	}

	if #role == "faucet" {
		template: "secrets/faucet.txt": {
			env:         true
			change_mode: "noop"
			data:        """
			COINBASE={{- with secret "kv/data/nomad-cluster/\(#namespace)/\(#wallet)/coinbase" -}}{{ .Data.data.value }}{{- end -}}
			"""
		}

		template: "secrets/account": {
			change_mode: "noop"
			data:        """
			{{- with secret "kv/data/nomad-cluster/\(#namespace)/\(#wallet)/account" -}}
			{{.Data.data | toJSON }}
			{{- end -}}
			"""
		}

	}

	template: "local/mantis.conf": {
		#roleConf: string

		if #role == "miner" {
			#roleConf: """
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
			#roleConf: """
				mantis.consensus.mining-enabled = false
				"""
		}

		if #role == "faucet" {
			#roleConf: """
			mantis.consensus.mining-enabled = false
			faucet {
			  # Base directory where all the data used by the fauced is stored
			  datadir = "/local/mantis-faucet"
			
			  # Wallet address used to send transactions from
			  {{ with secret "kv/nomad-cluster/\(#namespace)/\(#wallet)/coinbase" }}
			  wallet-address = "{{.Data.data.value}}"
			  {{ end }}
			
			  # Password to unlock faucet wallet
			  wallet-password = ""
			
			  # Path to directory where wallet key is stored
			  keystore-dir = "/secrets/keystore"
			
			  # Transaction gas price
			  tx-gas-price = 20000000000
			
			  # Transaction gas limit
			  tx-gas-limit = 90000
			
			  # Transaction value
			  tx-value = 1000000000000000000
			
			  # Address of Ethereum node used to send the transaction
				{{ range service "\(#wallet).\(#namespace)-mantis-miner-rpc" }}
				rpc-address = "http://{{ .Address }}:{{ .Port }}"
				{{ end }}
			
			  # How often can a single IP address send a request
			  min-request-interval = 1.minute
			
			  # Response time-out to get handler actor
			  handler-timeout = 1.seconds
			
			  # Response time-out from actor resolve
			  response-timeout = 3.seconds
			
			  # Supervisor with BackoffSupervisor pattern
			  supervisor {
			    min-backoff = 3.seconds
			    man-backoff = 30.seconds
			    random-factor = 0.2
			    auto-reset = 10.seconds
			    attempts = 4
			    delay = 0.1
			  }
			
			  # timeout for shutting down the ActorSystem
			  shutdown-timeout = 15.seconds
			}
			
			mantis {
			  network {
			    rpc {
			      http {
			        mode = "http"
			        enabled = false
			        interface = "0.0.0.0"
				      port = {{ env "NOMAD_PORT_rpc" }}
			        certificate-keystore-path = null
			        certificate-keystore-type = null
			        certificate-password-file = null
			        cors-allowed-origins = "*"
			      }
			
			      ipc {
			        enabled = false
			        socket-file = ${faucet.datadir}"/mantis.ipc"
			      }
			
			      apis = "faucet"
			    }
			  }
			}
			"""
		}

		#networkConf: string

		if #network != "testnet-internal-nomad" {
			#networkConf: ""
		}

		if #network == "testnet-internal-nomad" {
			#networkConf: """
				blockchains.testnet-internal-nomad = {
					custom-genesis-file = "/local/genesis.json"
					allowed-miners = []
				}
				"""
		}

		change_mode: "noop"
		splay:       "30m"
		data:        """
		include "/conf/base.conf"
		include "/conf/\(#network).conf"

		\(#mantisBaseConfig)

		logging.json-output = false
		logging.logs-file = "logs"

		mantis = {
			\(#networkConf)

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

		\(#roleConf)
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
