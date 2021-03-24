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

geneses: {
	"mantis-kevm": #genesis & {nonce: "0x0000000000000066", #networkId: 102}
	"mantis-evm":  #genesis & {nonce: "0x0000000000000067", #networkId: 103}
	"mantis-iele": #genesis & {nonce: "0x0000000000000068", #networkId: 104}
}

#defaults: {
	mantisRev: "9e95b1fce9f18efeea2d47191f7d2c21a18e1559"
}

#domain: "portal.dev.cardano.org"

#explorer: jobDef.#Explorer

#faucet: jobDef.#Faucet

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
			#id:          "evm"
			#fqdn:        "-\(#id).\(#domain)"
			#mantisRev:   #defaults.mantisRev
			#extraConfig: """
				mantis {
				  blockchains {
				    testnet-internal-nomad {
				      ecip1098-block-number = 0
				      ecip1097-block-number = 0
				      eip161-block-number = 0
				      chain-id = "\(geneses["mantis-evm"].nonce)"
				      network-id = \(geneses["mantis-evm"].#networkId)
				    }
				  }
				  sync.broadcast-new-block-hashes = true
				  consensus.protocol = "ethash"
				  vm.mode = "internal"
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
			#id:          "iele"
			#fqdn:        "-\(#id).\(#domain)"
			#mantisRev:   #defaults.mantisRev
			#extraConfig: """
				mantis {
				  blockchains {
				    testnet-internal-nomad {
				      ecip1098-block-number = 0
				      ecip1097-block-number = 0
				      eip161-block-number = 0
				      chain-id = "\(geneses["mantis-iele"].nonce)"
				      network-id = \(geneses["mantis-iele"].#networkId)
				    }
				  }
				  sync.broadcast-new-block-hashes = true
				  consensus.protocol = "ethash"
				  vm {
				    mode = "external"
				    external {
				      vm-type = "iele"
				      run-vm = true
				      executable-path = "iele-vm"
				      host = "127.0.0.1"
				      port = {{ env "NOMAD_PORT_vm" }}
				    }
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
			#id:          "kevm"
			#fqdn:        "-\(#id).\(#domain)"
			#mantisRev:   #defaults.mantisRev
			#extraConfig: """
				mantis {
				  blockchains {
				    testnet-internal-nomad {
				      ecip1098-block-number = 0
				      ecip1097-block-number = 0
				      eip161-block-number = 0
				      chain-id = "\(geneses["mantis-kevm"].nonce)"
				      network-id = \(geneses["mantis-kevm"].#networkId)
				    }
				  }
				  sync.broadcast-new-block-hashes = true
				  consensus.protocol = "ethash"
				  vm {
				    mode = "external"
				    external {
				      vm-type = "kevm"
				      run-vm = true
				      executable-path = "kevm-vm"
				      host = "127.0.0.1"
				      port = {{ env "NOMAD_PORT_vm" }}
				    }
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
	// output is alphabetical, so better errors show at the end.
	zchecks: "\(nsName)": {
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
