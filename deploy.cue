package bitte

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	jobDef "github.com/input-output-hk/mantis-ops/pkg/jobs:jobs"
	"list"
)

#defaultJobs: {
}

_Namespace: [Name=_]: {
	args: {
		namespace: =~"^mantis-[a-z-]+$"
		namespace: Name
		let datacenter = "eu-central-1" | "us-east-2" | "eu-west-1"
		datacenters: list.MinItems(1) | [...datacenter] | *["eu-central-1", "us-east-2"]
		fqdn:        "mantis.ws"
		network:     string
	}
	jobs: [string]: types.#stanza.job
}

#namespaces: _Namespace

#defaults: {
	mantisOpsRev: "a765196f47acf6ada8156e29b6cac1c561fb4692"
	mantisRev:    "7284a93c88168a2cfd3e1aa3988ff85542952e91"
	morphoRev:    "a765196f47acf6ada8156e29b6cac1c561fb4692"
}

#namespaces: {
	"mantis-unstable": {
		args: network: "sagano"
		jobs: {
			explorer: jobDef.#Explorer & {#args: {
				mantisOpsRev: #defaults.mantisOpsRev
			}}
			faucet: jobDef.#Faucet & {#args: {
				mantisOpsRev: #defaults.mantisOpsRev
			}}
			"miner": jobDef.#Mantis & {#args: {
				count:     3
				role:      "miner"
				mantisRev: #defaults.mantisRev
			}}
			"passive": jobDef.#Mantis & {#args: {
				count:     1
				role:      "passive"
				mantisRev: #defaults.mantisRev
			}}
			"morpho": jobDef.#Morpho & {#args: {
				count:     5
				morphoRev: #defaults.morphoRev
				mantisRev: #defaults.mantisRev
			}}
		}
	}
	"mantis-testnet": {
		args: network: "sagano"
		jobs: {
			explorer: jobDef.#Explorer & {#args: {
				mantisOpsRev: #defaults.mantisOpsRev
			}}
			faucet: jobDef.#Faucet & {#args: {
				mantisOpsRev: #defaults.mantisOpsRev
			}}
			"miner": jobDef.#Mantis & {#args: {
				count:     5
				role:      "miner"
				mantisRev: #defaults.mantisRev
			}}
			"passive": jobDef.#Mantis & {#args: {
				count:     2
				role:      "passive"
				mantisRev: #defaults.mantisRev
			}}
			"morpho": jobDef.#Morpho & {#args: {
				count:     5
				morphoRev: #defaults.morphoRev
				mantisRev: #defaults.mantisRev
			}}
		}
	}
	// "mantis-iele": jobs:        #defaultJobs
	// "mantis-qa-load": jobs:     #defaultJobs
	// "mantis-qa-fastsync": jobs: #defaultJobs
	// "mantis-staging": jobs:     #defaultJobs
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
