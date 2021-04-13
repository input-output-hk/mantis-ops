package mantis

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	jobDef "github.com/input-output-hk/mantis-ops/pkg/jobs:jobs"
	"list"
)

#defaults: {
	mantisRev: "b6a26f8624cd6bbf0467a97bbd42c99d3db021a0"
	// Temporary mantisRev to be re-unified when tested on other networks
	mantisRevEVM:  "24f34e15090ac624285c3f2719feef2809abe17f"
	mantisRevKEVM: "24f34e15090ac624285c3f2719feef2809abe17f"
}

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
			#mantisRev:   #defaults.mantisRevEVM
			#genesis:     geneses["mantis-\(#id)"]
			#extraConfig: """
				mantis {
				  blockchains {
				    testnet-internal-nomad {
				      ecip1098-block-number = 0
				      ecip1097-block-number = 0
				      eip161-block-number = 0
				      chain-id = "\(#genesis.nonce)"
				      network-id = \(#genesis.#networkId)
				      bootstrap-nodes = [
				        "enode://bc02e65c4c8417eda163d52b058910a8f5a39897501973b7f09415599b3c8bf4f2a163d6bb0aa6a8afbb2fc286bbd36fae95ff7a10b320a47cee382fcfa037c0@mantis-evm-0.portal.dev.cardano.org:31000?discport=31500",
				        "enode://430587ebbe28e0439de323d0010089b11ce0e30111b97f4edcf98ca6a6bb7f777910645edab91191010dda9353b9762f52620f36eef5cf855534f6f49ba2f68e@mantis-evm-1.portal.dev.cardano.org:31001?discport=31501",
				        "enode://720b4f7bbdbb8c8f0fcd00fe33c80acdb4c5c6074ab31db708ecf18a7fa2fcf646ac4188287e46acf6ce82bc0bd7029596d54584d1145b7591bc3ac9965d295c@mantis-evm-2.portal.dev.cardano.org:31002?discport=31502",
				        "enode://15d1e4fe385ad848636f0bb7707671fc7ff042a58b674072c981ac3293fdb3e2af1eb1f5510bacfa0616be76055e2bc9c120a845e8cf47ee2795722d07f7e69c@mantis-evm-3.portal.dev.cardano.org:31003?discport=31503",
				        "enode://98d6b58f9685b2678d56e58569656ff131a146a8ac0841bfe42ad3b5d8495b1fb271b967566baf254081e3823b086f1a0e7923cbc5c6ee6af5c2035e891f1fb8@mantis-evm-4.portal.dev.cardano.org:31004?discport=31504",
				      ]
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
			#genesis:     geneses["mantis-\(#id)"]
			#extraConfig: """
				mantis {
				  blockchains {
				    testnet-internal-nomad {
				      ecip1098-block-number = 0
				      ecip1097-block-number = 0
				      eip161-block-number = 0
				      chain-id = "\(#genesis.nonce)"
				      network-id = \(#genesis.#networkId)
				      bootstrap-nodes = [
				        "enode://51c22176f55e7cffe6cca1fcc969d5b532d0023ec3f640294e7309d58803080d5e6c7321071ca166c646552fea78b00002c47579b8cb69eefb52446cf0e307f1@mantis-iele-0.portal.dev.cardano.org:32000?discport=32500",
				        "enode://fff3b47315795f46fd498df4262ff4572819b1f95b4af899a3d6342625f6d864e74c50e3caaff1333b9ac8f5c797edcc0bba4dd242da899b0c7b5d545981eb64@mantis-iele-1.portal.dev.cardano.org:32001?discport=32501",
				        "enode://214718e0949248e1b98c6021ea91fb1eb9145c1295b4cbdaf856dc7e089bb20bfeb626004ab0ab49404b0dbbf84767cc661decb1d1e78ad5751b10efc442c4e8@mantis-iele-2.portal.dev.cardano.org:32002?discport=32502",
				        "enode://f1ec82b56346ede0258d7d357e9bce94f255f17d87cfc63551ab3b9760d5c2cca7f38b7bd3a7ff4d870736587843bb92fd519c7cf5b8d66429b89d04979fb59f@mantis-iele-3.portal.dev.cardano.org:32003?discport=32503",
				        "enode://9190f11ce563a3767d387368847811cb7616de97971377c572c659f0bcb08b9057d89b8f2800f0c6cb6a602b2b5807e1986d8da2f48ead33deefbf9c07f30125@mantis-iele-4.portal.dev.cardano.org:32004?discport=32504",
				      ]
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
			#mantisRev:   #defaults.mantisRevKEVM
			#genesis:     geneses["mantis-\(#id)"]
			#extraConfig: """
				mantis {
				  blockchains {
				    testnet-internal-nomad {
				      ecip1098-block-number = 0
				      ecip1097-block-number = 0
				      eip161-block-number = 0
				      chain-id = "\(#genesis.nonce)"
				      network-id = \(#genesis.#networkId)
				      bootstrap-nodes = [
				       "enode://aaca3067577e23ddfde8d3d5b39bca749edce4fe15b155ea6b6c977626468236a06547f1da7a28cd9c532b3c8aa1c646ad8d8c9ee03149a8d13e22038af4d100@mantis-kevm-0.portal.dev.cardano.org:30000?discport=30500",
				       "enode://17131d76d4d26e8b1e9868d8be84d247faf18a9fb320301f0f03cdcf18c9e8144ebb15ca550a4986d39cbe647de4e14da481baf1b8acd60ba5870c97e9a31429@mantis-kevm-1.portal.dev.cardano.org:30001?discport=30501",
				       "enode://62a25028b1d1871aa6c8df632fdcd8afae9a9e8c2db49bb4404f41c6c5f9df83d5d073a7a171578290dc717d157afab8c7ca302c279509c3f475fa95cd51727b@mantis-kevm-2.portal.dev.cardano.org:30002?discport=30502",
				       "enode://7280e95694ca236c6baf3b3be4cd141b3f2fb206bae63e47f568f7e2b036d813183a8d60847165cefd1de4e89f61f66b76032382d0d08b8b7d860922d7aa5f45@mantis-kevm-3.portal.dev.cardano.org:30003?discport=30503",
				       "enode://01b5276ef750f2c4b4884ac52643db44df6660d9006464ec512de14edee39e912c6af1db9a0ae5cd2448e33a6b3a5de6f54b8ad28b740fa20ffb971c262060c8@mantis-kevm-4.portal.dev.cardano.org:30004?discport=30504",
				      ]
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
