package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
)

#Backup: types.#stanza.task & {
	#namespace:           string
	#mantisOpsRev:        types.#gitRevision
	#networkConfig:       string
	#amountOfMorphoNodes: 5

	driver: "exec"

	resources: {
		cpu:    5000
		memory: 3 * 1024
	}

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	config: {
		flake:   "github:input-output-hk/mantis-ops?rev=\(#mantisOpsRev)#restic-backup"
		command: "/bin/restic-backup"
		args: ["--tag", #namespace]
	}

	template: "secrets/env.txt": {
		data: """
			AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
			AWS_DEFAULT_REGION="us-east-1"
			AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
			RESTIC_PASSWORD="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.password}}{{end}}"
			RESTIC_REPOSITORY="s3:http://{{ with node "monitoring" }}{{ .Node.Address }}{{ end }}:9000/restic"
			MONITORING_URL="http://{{ with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428/api/v1/query"
			"""
		env: true
	}

	template: "local/genesis.json": {
		data:        """
			{{- with secret "kv/nomad-cluster/\(#namespace)/genesis" -}}
			{{.Data.data | toJSON }}
			{{- end -}}
			"""
		change_mode: "noop"
	}

	template: "local/mantis.conf": {
		change_mode: "noop"
		splay:       "1h"
		data:        """
			logging.json-output = false
			logging.logs-file = "logs"
			logging.logs-level = "INFO"
			
			include "/conf/base.conf"
			include "/conf/testnet-internal-nomad.conf"
			
			mantis = {
			  consensus.mining-enabled = false
			  blockchains.testnet-internal-nomad = {
			    custom-genesis-file = "/local/genesis.json"
			    allowed-miners = []
			  }
			
			  client-id = "mantis-backup-{{env "NOMAD_ALLOC_INDEX"}}"
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
			
			\(#networkConfig)
			"""
	}
}
