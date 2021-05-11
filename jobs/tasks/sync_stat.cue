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

	config: {
		flake:   "github:input-output-hk/mantis-ops/mainnet-node?dir=pkgs/syncstat#syncstat"
		command: "/bin/syncstat"
	}

	leader: true

	env: {
		RUST_LOG: "INFO"
	}

	template: "env.txt": {
		env: true
		data: """
			RPC_NODE="http://{{ env "NOMAD_ADDR_rpc" }}"
			"""
	}
}
