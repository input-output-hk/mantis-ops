package bitte

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	jobDef "github.com/input-output-hk/mantis-ops/pkg/jobs:jobs"
)

let fqdn = "mantis.ws"

#defaultJobs: {
}

_Namespace: [Name=_]: {
	args: {
		namespace: =~"^mantis-[a-z-]+$"
		namespace: Name
		let datacenter = "eu-central-1" | "us-east-2" | "eu-west-1"
		datacenters: [...datacenter] | *["eu-central-1", "us-east-2"]
	}
	jobs: [string]: types.#stanza.job
}

#namespaces: _Namespace

#defaults: {
	mantisRev: "65cdd1db0b143c5cf200331493a67066581f65d8"
	morphoRev: "eb1eee7900ffb57826ded4387dca0d97c7e39861"
}

#namespaces: {
	"mantis-unstable": {
		jobs: {
			explorer: jobDef.#Explorer & {#args: {domain: "mantis-unstable-explorer.\(fqdn)"}}
			faucet:   jobDef.#Faucet & {#args: {domain:   "mantis-unstable-faucet.\(fqdn)"}}

			"miner":   jobDef.#Mantis & {#args: {count: 5, role: "miner", mantisRev:   #defaults.mantisRev}}
			"passive": jobDef.#Mantis & {#args: {count: 2, role: "passive", mantisRev: #defaults.mantisRev}}

			"morpho": jobDef.#Morpho & {#args: {count: 5, morphoRev: #defaults.morphoRev, mantisRev: #defaults.mantisRev}}
		}
	}
	"mantis-testnet": jobs: {
		jobs: {
			explorer: jobDef.#Explorer & {#args: {domain: "mantis-testnet-explorer.\(fqdn)"}}
			faucet:   jobDef.#Faucet & {#args: {domain:   "mantis-testnet-faucet.\(fqdn)"}}

			"miner":   jobDef.#Mantis & {#args: {count: 5, role: "miner", mantisRev:   #defaults.mantisRev}}
			"passive": jobDef.#Mantis & {#args: {count: 2, role: "passive", mantisRev: #defaults.mantisRev}}

			"morpho": jobDef.#Morpho & {#args: {count: 5, morphoRev: #defaults.morphoRev, mantisRev: #defaults.mantisRev}}
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
