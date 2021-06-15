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
		attempts: 1
		delay:    "1m"
		mode:     "fail"
	}

	config: {
		flake:   "github:input-output-hk/mantis-ops?dir=pkgs/syncstat&rev=1aa954ebeceb95852b8b594f9b4ac3ff95e3de7a#syncstat"
		command: "/bin/syncstat"
		// number of hours to run the node
		args: ["18"]
	}

	leader: true

	env: {
		RUST_LOG: "DEBUG"
	}

	template: "env.txt": {
		env: true
		data: """
			RPC_NODE="http://{{ env "NOMAD_ADDR_rpc" }}"
			SLACK_PATH="{{with secret "kv/nomad-cluster/mainnet/slack"}}{{.Data.data.path}}{{end}}"
			"""
	}
}
