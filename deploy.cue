package bitte

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	jobDef "github.com/input-output-hk/mantis-ops/pkg/jobs:jobs"
)

let fqdn = "mantis.ws"

#defaultJobs: {
}

_Namespace: [Name=_]: {
	vars: {
		let datacenter = "eu-central-1" | "us-east-2" | "eu-west-1"
		#dockerImages: dockerImages
		namespace:     =~"^mantis-[a-z-]+$"
		namespace:     Name
		datacenters:   [...datacenter] | *["eu-central-1", "us-east-2"]
	}
	jobs: [string]: types.#stanza.job
}

#namespaces: _Namespace

#namespaces: {
	"mantis-testnet": {
		jobs: {
			// explorer:   jobDef.#Explorer & {#domain: "mantis-testnet-explorer.\(fqdn)"}
			// faucet:     jobDef.#Faucet & {#domain:   "mantis-testnet-faucet.\(fqdn)"}
			"morpho-1": jobDef.#Morpho & {}
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
				#job:     jValue & nsValue.vars
			}
		}
	}
}
