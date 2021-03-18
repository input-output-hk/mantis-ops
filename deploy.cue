package mantis

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	jobDef "github.com/input-output-hk/mantis-ops/pkg/jobs:jobs"
	"list"
)

#namespaces: [Name=_]: {
	args: {
		namespace: =~"^mantis-[a-z-]+$"
		namespace: Name
		let datacenter = "eu-central-1" | "us-east-2" | "eu-west-1"
		datacenters: list.MinItems(1) | [...datacenter] | *["eu-central-1", "us-east-2", "eu-west-1"]
	}
	jobs: [string]: types.#stanza.job
}

#defaults: {
	mantisOpsRev: "#asdfdasf"
	mantisRev:    "2e75b523b00a9708c0bdc78e4d73e96ec91ae4a3"
}

#domain: "portal.dev.cardano.org"

#namespaces: {
	"mantis-evm": {
		args: {
			fqdn: "-evm.\(#domain)"
		}
		jobs: {
			explorer: jobDef.#Explorer & {#args: {
				mantisOpsRev: #defaults.mantisOpsRev
			}}
			faucet: jobDef.#Faucet & {#args: {
				mantisOpsRev: #defaults.mantisOpsRev
			}}
			miner: jobDef.#Mantis & {#args: {
				count:     3
				role:      "miner"
				mantisRev: #defaults.mantisRev
			}}
		}
	}
}

for nsName, nsValue in #namespaces {
	checks: "\(nsName)": {
		for jName, jValue in nsValue.jobs {
			"\(jName)": jValue & {#args: jValue.#args & nsValue.args}
		}
	}
}

for nsName, nsValue in #namespaces {
	rendered: "\(nsName)": {
		for jName, jValue in nsValue.jobs {
			"\(jName)": Job: types.#toJson & {
				#jobName: jName
				#job:     jValue & {#args: jValue.#args & nsValue.args}
			}
		}
	}
}
