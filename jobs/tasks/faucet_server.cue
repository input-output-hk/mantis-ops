package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
)

#FaucetServer: types.#stanza.task & {
	#namespace:    string
	#wallet:       string
	#mantisOpsRev: string

	driver: "exec"

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	resources: {
		cpu:    100
		memory: 1024 * 3
	}

	config: {
		flake:   "github:input-output-hk/mantis-ops?rev=\(#mantisOpsRev)#mantis-faucet-server"
		command: "/bin/mantis-faucet-entrypoint"
		args: ["-Dconfig.file=running.conf"]
	}

	template: "secrets/account": {
		data: """
    {{- with secret "kv/data/nomad-cluster/\(#namespace)/\(#wallet)/account" -}}
    {{.Data.data | toJSON }}
    {{- end -}}
    """
	}

	template: "secrets/env": {
		env:  true
		data: """
    COINBASE={{- with secret "kv/data/nomad-cluster/\(#namespace)/\(#wallet)/coinbase" -}}{{ .Data.data.value }}{{- end -}}
    """
	}

	template: "local/genesis.json": {
		change_mode: "restart"
		data:        """
    {{- with secret "kv/nomad-cluster/\(#namespace)/genesis" -}}
    {{.Data.data | toJSON }}
    {{- end -}}
    """
	}

	template: "local/faucet.conf": {
		change_mode: "restart"
		data:        """
    include "/conf/base.conf"
    include "/conf/testnet-internal-nomad.conf"

    logging.json-output = false
    logging.logs-file = "logs"

    mantis = {
      blockchains.network = "testnet-internal-nomad"
      blockchains.testnet-internal-nomad = {
        custom-genesis-file = "/local/genesis.json"
        allowed-miners = []
      }

      client-id = "mantis-faucet"
      datadir = "/local/mantis"
      ethash.ethash-dir = "/local/ethash"

      metrics.enabled = true
      metrics.port = {{ env "NOMAD_PORT_metrics" }}

      network {
        server-address.port = {{ env "NOMAD_PORT_server" }}
        server-address.interface = "0.0.0.0"

        rpc {
          http {
            mode = "http"
            enabled = true
            interface = "0.0.0.0"
            port = {{ env "NOMAD_PORT_rpc" }}
            certificate = null
            cors-allowed-origins = "*"
            rate-limit {
              enabled = true

              # Size of stored timestamps for requests made from each ip
              latest-timestamp-cache-size = 1024

              # Time that should pass between requests
              # Reflecting Faucet Web UI configuration
              # https://github.com/input-output-hk/mantis-faucet-web/blob/main/src/index.html#L18
              min-request-interval = 24.hours
            }
          }

          ipc {
            # Whether to enable JSON-RPC over IPC
            enabled = false

            # Path to IPC socket file
            socket-file = "/local/mantis-faucet/faucet.ipc"
          }

          # Enabled JSON-RPC APIs over the JSON-RPC endpoint
          apis = "faucet"
        }
      }
    }

    faucet {
      datadir = "/local/mantis-faucet"

      # Wallet address used to send transactions from
      {{ with secret "kv/nomad-cluster/\(#namespace)/\(#wallet)/coinbase" }}
      wallet-address = "{{.Data.data.value}}"
      {{ end }}

      # Password to unlock faucet wallet
      wallet-password = ""

      # Path to directory where wallet key is stored
      keystore-dir = /secrets/keystore

      # Transaction gas price
      tx-gas-price = 20000000000

      # Transaction gas limit
      tx-gas-limit = 90000

      # Transaction value
      tx-value = 1000000000000000000

      rpc-client {
        # Address of Ethereum node used to send the transaction
        {{ range service "\(#wallet).\(#namespace)-mantis-miner-rpc" }}
        rpc-address = "http://{{ .Address }}:{{ .Port }}"
        {{ end }}

        # certificate of Ethereum node used to send the transaction when use HTTP(S)
        certificate = null

        # Response time-out from rpc client resolve
        timeout = 3.seconds
      }

      # How often can a single IP address send a request
      min-request-interval = 1.minute

      # Response time-out to get handler actor
      handler-timeout = 1.seconds

      # Response time-out from actor resolve
      actor-communication-margin = 1.seconds

      # Supervisor with BackoffSupervisor pattern
      supervisor {
        min-backoff = 3.seconds
        max-backoff = 30.seconds
        random-factor = 0.2
        auto-reset = 10.seconds
        attempts = 4
        delay = 0.1
      }

      # timeout for shutting down the ActorSystem
      shutdown-timeout = 15.seconds
    }
    """
	}
}
