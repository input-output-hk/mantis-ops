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

#genesis: {
	extraData:  "0x00"
	nonce:      string
	gasLimit:   "0x7A1200"
	difficulty: "0xF4240"
	ommersHash: "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"
	timestamp:  "0x5FA34080"
	coinbase:   "0x0000000000000000000000000000000000000000"
	mixHash:    "0x0000000000000000000000000000000000000000000000000000000000000000"
	alloc: {}
}

// irb(main):020:0> %w[evm kevm iele].map{|n| [n, "0x%016x" % n.unpack('H*')[0].to_i(16)] }.to_h
// => {"evm"=>"0x000000000065766d", "kevm"=>"0x000000006b65766d", "iele"=>"0x0000000069656c65"}

geneses: {
	"mantis-kevm": #genesis & {nonce: "0x0000000000000d00"}
	"mantis-evm":  #genesis & {nonce: "0x0000000000000d01"}
	"mantis-iele": #genesis & {nonce: "0x0000000000000d02"}
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
	#count: 5
	#role:  "miner"
}

#passive: jobDef.#Mantis & {
	#count: 2
	#role:  "passive"
}

#namespaces: {
	"mantis-evm": {
		args: {
			#fqdn:      "-evm.\(#domain)"
			#mantisRev: #defaults.mantisRev
			#extraConfig: """
				mantis.consensus {
				  protocol = "ethash"
				}
				mantis.vm {
				  mode = "internal"
				}
				"""
		}
		jobs: {
			explorer: #explorer
			faucet:   #faucet
			miner:    #miner
			passive:  #passive
		}
	}

	"mantis-iele": {
		args: {
			#fqdn:      "-iele.\(#domain)"
			#mantisRev: #defaults.mantisRev
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
		jobs: {
			explorer: #explorer
			faucet:   #faucet
			miner:    #miner
			passive:  #passive
		}
	}

	"mantis-kevm": {
		args: {
			#fqdn:      "-kevm.\(#domain)"
			#mantisRev: #defaults.mantisRev
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
		jobs: {
			explorer: #explorer
			faucet:   #faucet
			miner:    #miner
			passive:  #passive
		}
	}

	"mantis-cue": {
		args: {
			#fqdn:      "-cue.\(#domain)"
			#mantisRev: "dcddff81d49362e4b5b4f689fd7cbcf540f40cd6"
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
		jobs: {
			explorer: #explorer
			faucet:   #faucet
			miner:    #miner
			passive:  #passive
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
