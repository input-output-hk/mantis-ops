package bitte

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	jobDef "github.com/input-output-hk/mantis-ops/pkg/jobs:jobs"
	"list"
)

#defaultJobs: {
}

_Namespace: [Name=_]: {
	vars: {
		namespace: =~"^mantis-[a-z-]+$"
		namespace: Name
		let datacenter = "eu-central-1" | "us-east-2" | "eu-west-1"
		datacenters: list.MinItems(1) | [...datacenter] | *["eu-central-1", "us-east-2"]
		#fqdn:       "mantis.ws"
		#network:    string
	}
	jobs: [string]: types.#stanza.job
}

#namespaces: _Namespace

#defaults: {
	mantisOpsRev: "97dfa8601097e8e0cf52d2f62d2f57b5ddb8cd81"
	mantisRev:    "fdeb1c33f6e0fc24680e256fe1b8d920b04950a8"
	morphoRev:    "b4335fb4e764d5441445179d0e8d9e3e596e7d94"
}

#faucet: jobDef.#Faucet & {
	#mantisOpsRev: #defaults.mantisOpsRev
}

#explorer: jobDef.#Explorer & {
	#mantisOpsRev: #defaults.mantisOpsRev
}

#miner: jobDef.#Mantis & {
	#count:     uint | *1
	#role:      "miner"
	#mantisRev: #defaults.mantisRev
}

#passive: jobDef.#Mantis & {
	#count:     uint | *1
	#role:      "passive"
	#mantisRev: #defaults.mantisRev
}

#morpho: jobDef.#Morpho & {
	#count:     uint | *5
	#morphoRev: #defaults.morphoRev
	#mantisRev: #defaults.mantisRev
}

#namespaces: {
	"mantis-unstable": {
		vars: #network: "sagano"
		jobs: {
			explorer: #explorer
			faucet:   #faucet
			miner:    #miner
			passive:  #passive
			morpho:   #morpho
		}
	}
	"mantis-testnet": {
		vars: #network: "sagano"
		jobs: {
			explorer: #explorer
			faucet:   #faucet
			miner:    #miner & {#count:   5}
			passive:  #passive & {#count: 5}
			morpho:   #morpho
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

for nsName, nsValue in #namespaces {
	// output is alphabetical, so better errors show at the end.
	zchecks: "\(nsName)": {
		for jName, jValue in nsValue.jobs {
			"\(jName)": jValue & nsValue.vars
		}
	}
}
