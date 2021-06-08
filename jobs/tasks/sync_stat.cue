package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
)

#SyncStat: types.#stanza.task & {
	driver: "exec"

	resources: {
		cpu:    1000
		memory: 1 * 1024
	}

	restart: {
		interval: "1m"
		attempts: 0
		delay:    "1m"
		mode:     "fail"
	}

	config: {
		flake:   "github:input-output-hk/mantis-ops?dir=pkgs/syncstat&rev=70eef4a58de7d0f253881dad70171342537c7573#syncstat"
		command: "/bin/syncstat"
		// number of hours to run the node
		args: ["18"]
	}

	leader: true

	env: {
		RUST_LOG: "INFO"
	}

	template: "env.txt": {
		env: true
		data: """
			RPC_NODE="http://{{ env "NOMAD_ADDR_rpc" }}"
			SLACK_URL="{{with secret "kv/nomad-cluster/mainnet/slack"}}{{.Data.data.url}}{{end}}"
			"""
	}
}
