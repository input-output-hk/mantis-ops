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
		flake:   "github:input-output-hk/mantis-ops?dir=pkgs/syncstat&rev=0ed3cdc15796db034cd21b50f4f52563f6f1c7d0#syncstat"
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
			"""
	}
}
