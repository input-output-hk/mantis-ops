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
		flake:   "github:input-output-hk/mantis-ops/mainnet-node?dir=pkgs/syncstat"
		command: "/bin/syncstat"
	}

	leader: true

	env: {
		RPC_NODE: "http://${NOMAD_ADDR_mantis_rpc}"
	}

	// lifecycle: hook: "poststart"
}
