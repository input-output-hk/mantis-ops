package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"strconv"
)

#SyncStat: types.#stanza.task & {
	#hours: >0 | int
	driver: "exec"

	resources: {
		cpu:    1000
		memory: 1 * 1024
	}

	config: {
		flake:   "github:input-output-hk/mantis-ops?dir=pkgs/syncstat&rev=165244598a2d6ca5bef3bb5957f23eafad5d6f70#syncstat"
		command: "/bin/syncstat"
		// number of hours to run the node
		args: [strconv.FormatInt(#hours, 10)]
	}

	leader: true

	env: {
		RUST_LOG:      "INFO"
		SSL_CERT_FILE: "/etc/ssl/certs/ca-bundle.crt"
	}

	template: "env.txt": {
		env: true
		data: """
			RPC_NODE="http://{{ env "NOMAD_ADDR_rpc" }}"
			SLACK_PATH="{{with secret "kv/nomad-cluster/mainnet/slack"}}{{.Data.data.path}}{{end}}"
			"""
	}
}
