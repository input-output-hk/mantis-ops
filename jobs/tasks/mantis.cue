package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"list"
	"strings"
)

#Mantis: types.#stanza.task & {
	#namespace: string
	#role:      "passive" | "miner" | "backup"
	#mantisRev: string
	#network:   string
	#miners: []
	#amountOfMorphoNodes: 5
	#requiredPeerCount:   len(#miners)

	driver: "exec"

	if #role == "miner" {
		resources: {
			cpu:    7500
			memory: 6 * 1024
		}
	}

	if #role == "passive" || #role == "backup" {
		resources: {
			cpu:    5000
			memory: 3 * 1024
		}
	}

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	config: {
		flake:   "github:input-output-hk/mantis?rev=\(#mantisRev)#mantis"
		command: "/bin/mantis"
		args: ["-Dconfig.file=/local/mantis.conf", "-XX:ActiveProcessorCount=2"]
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
		#checkpointRange: list.Range(0, #amountOfMorphoNodes, 1)
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

		if #network != "sagano" && #network != "testnet-internal-nomad" {
			#saganoConf: ""
		}

		if #network == "sagano" {
			#saganoConf: """
			blockchains.testnet-internal-nomad = {
			  custom-genesis-file = "/local/genesis.json"
			  allowed-miners = []
			  bootstrap-nodes = [
			    "enode://f92aa66337ab1993cc7269d4295d296aefe6199b34e900eac08c514c947ec7340d46a5648ffc2da10325dbaba16bdf92aa9c0b5e51d97a7818c3f495d478ddad@mantis-testnet-0.mantis.ws:9001?discport=9501",
			    "enode://d8a010f019db37dcaf2e1fb98d4fcbf1f57dbd7e2a7f065e92fbe77dca8b9120d6e79f1617e98fa6134e6af8858ac8f3735b1e70a5708eb14f228080356eb0a7@mantis-testnet-1.mantis.ws:9002?discport=9502",
			    "enode://442e2bd50eece65f90dee0d5c6075da4e1b4bc62e36b261a52e7f393dae6a68241e4dbad868c7ecc14fed277ed72e99a289a811b6172f35fb18bdca0b7a5602c@mantis-testnet-2.mantis.ws:9003?discport=9503",
			    "enode://ff86741b7b35087b2b53f44a612b233336490d5fae10b1434619b7714fe2d5346c71427a5e126cd27b9422a4d4376c1534ef66e88c5e62d6441d2541f63de0cf@mantis-testnet-3.mantis.ws:9004?discport=9504",
			    "enode://af97643f364b805d5b0e32b5356578a16afcc4fb9d1b6622998e9441eeb7795e8daf8e6b0ff3330da9879034112be56954f9269164513ece0f7394b805be3633@mantis-testnet-4.mantis.ws:9005?discport=9505",
			  ]
			  checkpoint-public-keys = [
			    \(#checkPointKeysString)
			  ]
			}
			"""
		}

		if #network == "testnet-internal-nomad" {
			#saganoConf: """
			blockchains.testnet-internal-nomad = {
			  custom-genesis-file = "/local/genesis.json"
			  allowed-miners = []
			  bootstrap-nodes = [
			    "enode://cbd80c7f72a889101b7f23d51be2de7e3f1f46ad3b25c438e959e24e08f03bd9fe833460e84b60174d4eb120af3b127389c4606f81c842943c4922cab384a234@mantis-staging-0.mantis.ws:33000?discport=33500",
			    "enode://0e63642be49c5a092569aa01663fcda1505362cd0ac41e24ff9296ab80c97af135fb6fb247273631a3a11257774f39ed882d72a20fd45131e53e9015adf6b9e5@mantis-staging-1.mantis.ws:33001?discport=33501",
			    "enode://3ee3641a25cfc611ba54a898260af7768ecf0643f06aefedf853864ed433d5ad6265eeb24abcc4d6f6ee90a1eac6c1fbf157fc05fd8e28e194dfc864cb56058e@mantis-staging-2.mantis.ws:33002?discport=33502",
			    "enode://907842e336fc757bbfde70368aef329714aa627e72e5da687f31b097fa71a59f36404aebbc83885c9b515270042e025a6788b700c314ee8bc68099dcff32afcd@mantis-staging-3.mantis.ws:33003?discport=33503",
			    "enode://92958d370442cfbf3efc46b37a0a1608298d8118013bf86868aaa49305a58991e006857552a88ac3349c5da43b00df44e685b39982f61c2fdeb3582daecac476@mantis-staging-4.mantis.ws:33004?discport=33504",
			  ]
			  checkpoint-public-keys = [
			    \(#checkPointKeysString)
			  ]
			}
			"""
		}

		change_mode: "noop"
		splay:       "1h"
		data:        """
		include "/conf/base.conf"
		include "/conf/\(#network).conf"

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
