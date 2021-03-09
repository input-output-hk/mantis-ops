package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
)

#FaucetServer: types.#stanza.task & {
	#taskArgs: {
		namespace:    string
		wallet:       string
		mantisOpsRev: string
	}

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
		flake:   "github:input-output-hk/mantis-ops?rev=\(#taskArgs.mantisOpsRev)#mantis-faucet-server"
		command: "/bin/mantis-faucet-entrypoint"
		args: ["-Dconfig.file=running.conf"]
	}

	template: "secrets/account": {
		data: """
    {{- with secret "kv/data/nomad-cluster/\(#taskArgs.namespace)/\(#taskArgs.wallet)/account" -}}
    {{.Data.data | toJSON }}
    {{- end -}}
    """
	}

	template: "secrets/env": {
		env:  true
		data: """
    COINBASE={{- with secret "kv/data/nomad-cluster/\(#taskArgs.namespace)/\(#taskArgs.wallet)/coinbase" -}}{{ .Data.data.value }}{{- end -}}
    """
	}

	template: "local/genesis.json": {
		change_mode: "restart"
		data:        """
    {{- with secret "kv/nomad-cluster/\(#taskArgs.namespace)/genesis" -}}
    {{.Data.data | toJSON }}
    {{- end -}}
    """
	}

	template: "local/faucet.conf": {
		change_mode: "restart"
		data:        """
    faucet {
      # Base directory where all the data used by the faucet is stored
      datadir = "/local/mantis-faucet"

      # Wallet address used to send transactions from
      wallet-address =
        {{- with secret "kv/nomad-cluster/\(#taskArgs.namespace)/\(#taskArgs.wallet)/coinbase" -}}
          "{{.Data.data.value}}"
        {{- end }}

      # Password to unlock faucet wallet
      wallet-password = ""

      # Path to directory where wallet key is stored
      keystore-dir = {{ env "NOMAD_SECRETS_DIR" }}/keystore

      # Transaction gas price
      tx-gas-price = 20000000000

      # Transaction gas limit
      tx-gas-limit = 90000

      # Transaction value
      tx-value = 1000000000000000000

      rpc-client {
        # Address of Ethereum node used to send the transaction
        {{ range service "\(#taskArgs.wallet).\(#taskArgs.namespace)-mantis-miner-rpc" }}
          rpc-address = "http://{{ .Address }}:{{ .Port }}"
        {{ end }}

        # certificate of Ethereum node used to send the transaction when use HTTP(S)
        certificate = null
        #certificate {
        # Path to the keystore storing the certificates (used only for https)
        # null value indicates HTTPS is not being used
        #  keystore-path = "tls/mantisCA.p12"

        # Type of certificate keystore being used
        # null value indicates HTTPS is not being used
        #  keystore-type = "pkcs12"

        # File with the password used for accessing the certificate keystore (used only for https)
        # null value indicates HTTPS is not being used
        #  password-file = "tls/password"
        #}

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

    logging {
      # Flag used to switch logs to the JSON format
      json-output = false

      # Logs directory
      #logs-dir = /local/mantis-faucet/logs

      # Logs filename
      logs-file = "logs"
    }

    mantis {
      network {
        rpc {
          http {
            # JSON-RPC mode
            # Available modes are: http, https
            # Choosing https requires creating a certificate and setting up 'certificate-keystore-path' and
            # 'certificate-password-file'
            # See: https://github.com/input-output-hk/mantis/wiki/Creating-self-signed-certificate-for-using-JSON-RPC-with-HTTPS
            mode = "http"

            # Whether to enable JSON-RPC HTTP(S) endpoint
            enabled = true

            # Listening address of JSON-RPC HTTP(S) endpoint
            interface = "0.0.0.0"

            # Listening port of JSON-RPC HTTP(S) endpoint
            port = {{ env "NOMAD_PORT_rpc" }}

            certificate = null
            #certificate {
            # Path to the keystore storing the certificates (used only for https)
            # null value indicates HTTPS is not being used
            #  keystore-path = "tls/mantisCA.p12"

            # Type of certificate keystore being used
            # null value indicates HTTPS is not being used
            #  keystore-type = "pkcs12"

            # File with the password used for accessing the certificate keystore (used only for https)
            # null value indicates HTTPS is not being used
            #  password-file = "tls/password"
            #}

            # Domains allowed to query RPC endpoint. Use "*" to enable requests from
            # any domain.
            cors-allowed-origins = "*"

            # Rate Limit for JSON-RPC requests
            # Limits the amount of request the same ip can perform in a given amount of time
            rate-limit {
              # If enabled, restrictions are applied
              enabled = true

              # Time that should pass between requests
              # Reflecting Faucet Web UI configuration
              # https://github.com/input-output-hk/mantis-faucet-web/blob/main/src/index.html#L18
              min-request-interval = 24.hours

              # Size of stored timestamps for requests made from each ip
              latest-timestamp-cache-size = 1024
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
    """
	}
}
