{ lib, config, namespace, domain, dockerImages, mantis-faucet-source, vault, genesisJson, ... }:

let
  faucetName = "${namespace}-faucet";
in {
  networks = [{
    mode = "bridge";
    ports = {
      metrics.to = 7000;
      rpc.to = 8000;
      faucet-web.to = 8080;
    };
  }];

  services = {
    "${faucetName}" = {
      addressMode = "host";
      portLabel = "rpc";
      task = "faucet";

      tags =
        [ "ingress" namespace "faucet" faucetName mantis-faucet-source.rev ];

      meta = {
        name = faucetName;
        publicIp = "\${attr.unique.platform.aws.public-ipv4}";
        ingressHost = "faucet.${domain}";
        ingressBind = "*:443";
        ingressMode = "http";
        ingressServer = "_${faucetName}._tcp.service.consul";
        ingressBackendExtra = ''
          option forwardfor
          http-response set-header X-Server %s
        '';
        ingressFrontendExtra = ''
          reqidel ^X-Forwarded-For:.*
        '';
      };

      # FIXME: this always returns FaucetUnavailable
      # checks = [{
      #   taskName = "faucet";
      #   type = "script";
      #   name = "faucet_health";
      #   command = "healthcheck";
      #   interval = "60s";
      #   timeout = "5s";
      #   portLabel = "rpc";

      #   checkRestart = {
      #     limit = 5;
      #     grace = "300s";
      #     ignoreWarnings = false;
      #   };
      # }];
    };

    "${faucetName}-prometheus" = {
      addressMode = "host";
      portLabel = "metrics";
      tags = [
        "prometheus"
        namespace
        "faucet"
        faucetName
        mantis-faucet-source.rev
      ];
    };

    "${faucetName}-web" = {
      addressMode = "host";
      portLabel = "faucet-web";
      tags =
        [ "ingress" namespace "faucet" faucetName mantis-faucet-source.rev ];
      meta = {
        name = faucetName;
        publicIp = "\${attr.unique.platform.aws.public-ipv4}";
        ingressHost = "${faucetName}-web.${domain}";
        ingressBind = "*:443";
        ingressMode = "http";
        ingressServer = "_${faucetName}-web._tcp.service.consul";
      };
    };
  };

  tasks.faucet = {
    name = "faucet";
    driver = "docker";

    inherit vault;

    resources = {
      cpu = 100;
      memoryMB = 1024;
    };

    config = {
      image = dockerImages.mantis-faucet;
      args = [ "-Dconfig.file=running.conf" ];
      ports = [ "rpc" "metrics" ];
      labels = [{
        inherit namespace;
        name = "faucet";
        imageTag = dockerImages.mantis-faucet.image.imageTag;
      }];

      logging = {
        type = "journald";
        config = [{
          tag = "faucet";
          labels = "name,namespace,imageTag";
        }];
      };
    };

    templates = let
      secret = key: ''{{ with secret "${key}" }}{{.Data.data.value}}{{end}}'';
    in [
      {
        data = ''
          faucet {
            # Base directory where all the data used by the faucet is stored
            datadir = "/local/mantis-faucet"

            # Wallet address used to send transactions from
            wallet-address =
              {{- with secret "kv/nomad-cluster/${namespace}/mantis-1/coinbase" -}}
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
              rpc-address = {{- range service "mantis-1.${namespace}-mantis-miner-rpc" -}}
                  "http://{{ .Address }}:{{ .Port }}"
                {{- end }}

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
        '';
        changeMode = "restart";
        destination = "local/faucet.conf";
      }
      {
        data = ''
          {{- with secret "kv/data/nomad-cluster/${namespace}/mantis-1/account" -}}
          {{.Data.data | toJSON }}
          {{- end -}}
        '';
        destination = "secrets/account";
      }
      {
        data = ''
          COINBASE={{- with secret "kv/data/nomad-cluster/${namespace}/mantis-1/coinbase" -}}{{ .Data.data.value }}{{- end -}}
        '';
        destination = "secrets/env";
        env = true;
      }
      genesisJson
    ];
  };

  tasks.faucet-web = {
    name = "faucet-web";
    driver = "docker";
    resources = {
      cpu = 100;
      memoryMB = 128;
    };
    config = {
      image = dockerImages.mantis-faucet-web;
      args = [ "nginx" "-c" "/local/nginx.conf" ];
      ports = [ "faucet-web" ];
      labels = [{
        inherit namespace;
        name = "faucet-web";
        imageTag = dockerImages.mantis-faucet-web.image.imageTag;
      }];

      logging = {
        type = "journald";
        config = [{
          tag = "faucet-web";
          labels = "name,namespace,imageTag";
        }];
      };
    };
    templates = [{
      data = ''
        user nginx nginx;
        error_log /dev/stdout info;
        pid /dev/null;
        events {}
        daemon off;

        http {
          access_log /dev/stdout;

          types {
            text/css         css;
            text/javascript  js;
            text/html        html htm;
          }

          server {
            listen 8080;

            location / {
              root /mantis-faucet-web;
              index index.html;
              try_files $uri $uri/ /index.html;
            }

            {{ range service "${namespace}-mantis-faucet" -}}
            # https://github.com/input-output-hk/mantis-faucet-web/blob/nix-build/flake.nix#L14
            # TODO: the above FAUCET_NODE_URL should point to this
            location /rpc/node {
              proxy_pass  "http://{{ .Address }}:{{ .Port }}";
            }
            {{- end }}
          }
        }
      '';
      # TODO, make it signal when the above proxy_pass is used
      changeMode = "noop";
      changeSignal = "SIGHUP";
      destination = "local/nginx.conf";
    }];
  };

  tasks.telegraf = {
    driver = "docker";

    inherit vault;

    resources = {
      cpu = 100; # mhz
      memoryMB = 128;
    };

    config = {
      image = dockerImages.telegraf;
      args = [ "-config" "local/telegraf.config" ];

      labels = [{
        inherit namespace;
        name = "faucet";
        imageTag = dockerImages.telegraf.image.imageTag;
      }];

      logging = {
        type = "journald";
        config = [{
          tag = "faucet-telegraf";
          labels = "name,namespace,imageTag";
        }];
      };
    };

    templates = [{
      data = ''
        [agent]
        flush_interval = "10s"
        interval = "10s"
        omit_hostname = false

        [global_tags]
        client_id = "faucet"
        namespace = "${namespace}"

        [inputs.prometheus]
        metric_version = 1

        urls = [ "http://{{ env "NOMAD_ADDR_metrics" }}" ]

        [outputs.influxdb]
        database = "telegraf"
        urls = [ {{ with node "monitoring" }}"http://{{ .Node.Address }}:8428"{{ end }} ]
      '';

      destination = "local/telegraf.config";
    }];
  };
}

