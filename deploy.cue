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

		#network: string | *"testnet-internal-nomad"
	}
	jobs: [string]: types.#stanza.job
}

#defaults: {
	mantisOpsRev: "a765196f47acf6ada8156e29b6cac1c561fb4692"
	mantisRev:    "2e75b523b00a9708c0bdc78e4d73e96ec91ae4a3"
}

#domain: "portal.dev.cardano.org"

#explorer: jobDef.#Explorer & {
	#mantisOpsRev: #defaults.mantisOpsRev
}

#faucet: jobDef.#Faucet & {
	#mantisOpsRev: #defaults.mantisOpsRev
}

#miner: jobDef.#Mantis & {
	#count:     5
	#role:      "miner"
	#mantisRev: #defaults.mantisRev
}

#passive: jobDef.#Mantis & {
	#count:     2
	#role:      "passive"
	#mantisRev: #defaults.mantisRev
}

#namespaces: {
	"mantis-evm": {
		args: {
			#fqdn: "-evm.\(#domain)"
		}
		jobs: {
			explorer: #explorer
			faucet:   #faucet
			miner:    #miner & {
				#extraConfig: """
					mantis.consensus {
					  protocol = "ethash"
					}
					mantis.vm {
					  mode = "internal"
					}
					"""
			}
			passive: #passive
		}
	}

	"mantis-iele": {
		args: {
			#fqdn: "-iele.\(#domain)"
		}
		jobs: {
			explorer: #explorer
			faucet:   #faucet
			miner:    #miner & {
				#extraConfig: """
					mantis.vm {
					  mode = "external"
					  external {
					    vm-type = "kevm"
					    run-vm = true
					    executable-path = "/bin/kevm-vm"
					    host = "127.0.0.1"
					    port = {{ env "NOMAD_PORT_vm" }}
					  }
					}
					"""
			}
			passive: #passive
		}
	}

	"mantis-kevm": {
		args: {
			#fqdn: "-kevm.\(#domain)"
		}
		jobs: {
			explorer: #explorer
			faucet:   #faucet
			miner:    #miner & {
				#extraConfig: """
					mantis.consensus {
					  protocol = "restricted-ethash"
					}
					mantis.vm {
					  mode = "external"
					  external {
					    vm-type = "kevm"
					    run-vm = true
					    executable-path = "/bin/kevm-vm"
					    host = "127.0.0.1"
					    port = {{ env "NOMAD_PORT_vm" }}
					  }
					}
					"""
			}
			passive: #passive
		}
	}
}

for nsName, nsValue in #namespaces {
	checks: "\(nsName)": {
		for jName, jValue in nsValue.jobs {
			"\(jName)": jValue & nsValue.args
		}
	}
}

for nsName, nsValue in #namespaces {
	rendered: "\(nsName)": {
		for jName, jValue in nsValue.jobs {
			"\(jName)": Job: types.#toJson & {
				#jobName: jName
				#job:     jValue & nsValue.args
			}
		}
	}
}
