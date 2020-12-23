{ mkNomadJob, lib, mantis, mantis-source, mantis-faucet, mantis-faucet-source
, morpho-node, morpho-source, dockerImages, mantis-explorer }:
let
  # NOTE: Copy this file and change the next line if you want to start your own cluster!
  namespace = "mantis-staging";

  vault = {
    policies = [ "nomad-cluster" ];
    changeMode = "noop";
  };

  genesisJson = {
    data = ''
      {{- with secret "kv/nomad-cluster/${namespace}/genesis" -}}
      {{.Data.data | toJSON }}
      {{- end -}}
    '';
    changeMode = "restart";
    destination = "local/genesis.json";
  };

  amountOfMorphoNodes = 5;

  morphoNodes = lib.forEach (lib.range 1 amountOfMorphoNodes) (n: {
    inherit namespace morpho-source vault dockerImages;
    name = "obft-node-${toString n}";
    nodeNumber = n;
  });

  mkMantis = { name, resources, count ? 1, templates, serviceName, tags ? [ ]
    , serverMeta ? { }, meta ? { }, discoveryMeta ? { }, requiredPeerCount
    , services ? { } }: {
      inherit count;

      networks = [{
        mode = "bridge";
        ports = {
          discovery.to = 6000;
          metrics.to = 7000;
          rpc.to = 8000;
          server.to = 9000;
        };
      }];

      ephemeralDisk = {
        sizeMB = 10 * 1000;
        migrate = true;
        sticky = true;
      };

      reschedulePolicy = {
        attempts = 0;
        unlimited = true;
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
            inherit namespace name;
            imageTag = dockerImages.telegraf.image.imageTag;
          }];

          logging = {
            type = "journald";
            config = [{
              tag = "${name}-telegraf";
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
            client_id = "${name}"
            namespace = "${namespace}"

            [inputs.prometheus]
            metric_version = 1

            urls = [ "http://127.0.0.1:{{ env "NOMAD_PORT_metrics" }}" ]

            [outputs.influxdb]
            database = "telegraf"
            urls = [ {{ with node "monitoring" }}"http://{{ .Node.Address }}:8428"{{ end }} ]
          '';

          destination = "local/telegraf.config";
        }];
      };

      services = lib.recursiveUpdate {
        "${serviceName}-prometheus" = {
          addressMode = "host";
          portLabel = "metrics";
          tags = [ "prometheus" namespace serviceName name mantis-source.rev ];
        };

        "${serviceName}-rpc" = {
          addressMode = "host";
          portLabel = "rpc";
          tags = [ "rpc" namespace serviceName name mantis-source.rev ];
        };

        "${serviceName}-discovery" = {
          portLabel = "discovery";
          tags = [ "discovery" namespace serviceName name mantis-source.rev ]
            ++ tags;
          meta = {
            inherit name;
            publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          } // discoveryMeta;
        };

        "${serviceName}-server" = {
          portLabel = "server";
          tags = [ "server" namespace serviceName name mantis-source.rev ]
            ++ tags;
          meta = {
            inherit name;
            publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          } // serverMeta;
        };

        ${serviceName} = {
          addressMode = "host";
          portLabel = "server";

          tags = [ "server" namespace serviceName mantis-source.rev ] ++ tags;

          meta = {
            inherit name;
            publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          } // meta;
        };
      } services;

      tasks.${name} = {
        inherit name resources templates;
        driver = "docker";
        inherit vault;

        config = {
          image = dockerImages.mantis;
          args = [ "-Dconfig.file=running.conf" ];
          ports = [ "rpc" "server" "metrics" "discovery" ];
          labels = [{
            inherit namespace name;
            imageTag = dockerImages.mantis.image.imageTag;
          }];

          logging = {
            type = "journald";
            config = [{
              tag = name;
              labels = "name,namespace,imageTag";
            }];
          };
        };

        restartPolicy = {
          interval = "30m";
          attempts = 10;
          delay = "1m";
          mode = "fail";
        };

        env = { REQUIRED_PEER_COUNT = toString requiredPeerCount; };
      };
    };

  mkMiner = { name, publicDiscoveryPort, publicServerPort, requiredPeerCount ? 0
    , instanceId ? null }:
    lib.nameValuePair name (mkMantis {
      resources = {
        # For c5.2xlarge in clusters/mantis/testnet/default.nix, the url ref below
        # provides 3.4 GHz * 8 vCPU = 27.2 GHz max.
        # Mantis mainly uses only one core.
        # Allocating by vCPU or core quantity not yet available.
        # Ref: https://github.com/hashicorp/nomad/blob/master/client/fingerprint/env_aws.go
        cpu = 3400;
        memoryMB = 5 * 1024;
      };

      inherit name requiredPeerCount;
      templates = [
        {
          data = ''
            include "${mantis}/conf/testnet-internal-nomad.conf"

            logging.json-output = true
            logging.logs-file = "logs"

            mantis.blockchains.testnet-internal-nomad.bootstrap-nodes = [
              {{ range service "${namespace}-mantis-miner-server" -}}
                "enode://  {{- with secret (printf "kv/data/nomad-cluster/${namespace}/%s/enode-hash" .ServiceMeta.Name) -}}
                  {{- .Data.data.value -}}
                  {{- end -}}@{{ .Address }}:{{ .Port }}",
              {{ end -}}
            ]

            mantis.blockchains.testnet-internal-nomad.checkpoint-public-keys = [
              ${
                lib.concatMapStringsSep "," (x: ''
                  {{- with secret "kv/data/nomad-cluster/${namespace}/obft-node-${
                    toString x
                  }/obft-public-key" -}}"{{- .Data.data.value -}}"{{end}}
                '') (lib.range 1 amountOfMorphoNodes)
              }
            ]

            mantis.consensus.mining-enabled = true
            mantis.client-id = "${name}"
            mantis.consensus.coinbase = "{{ with secret "kv/data/nomad-cluster/${namespace}/${name}/coinbase" }}{{ .Data.data.value }}{{ end }}"
            mantis.node-key-file = "{{ env "NOMAD_SECRETS_DIR" }}/secret-key"
            mantis.datadir = "/local/mantis"
            mantis.ethash.ethash-dir = "/local/ethash"
            mantis.metrics.enabled = true
            mantis.metrics.port = {{ env "NOMAD_PORT_metrics" }}
            mantis.network.discovery.discovery-enabled = true
            mantis.network.discovery.host = {{ with node "monitoring" }}"{{ .Node.Address }}"{{ end }}
            mantis.network.discovery.port = ${toString publicDiscoveryPort}
            mantis.network.rpc.http.interface = "0.0.0.0"
            mantis.network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}
            mantis.network.server-address.port = {{ env "NOMAD_PORT_server" }}
            mantis.blockchains.testnet-internal-nomad.custom-genesis-file = "{{ env "NOMAD_TASK_DIR" }}/genesis.json"
            mantis.blockchains.testnet-internal-nomad.allowed-miners = []

            mantis.blockchains.testnet-internal-nomad.ecip1098-block-number = 0
            mantis.blockchains.testnet-internal-nomad.ecip1097-block-number = 0
          '';
          changeMode = "noop";
          destination = "local/mantis.conf";
          splay = "15m";
        }
        {
          data = let
            secret = key:
              ''{{ with secret "${key}" }}{{.Data.data.value}}{{end}}'';
          in ''
            ${secret "kv/data/nomad-cluster/${namespace}/${name}/secret-key"}
            ${secret "kv/data/nomad-cluster/${namespace}/${name}/enode-hash"}
          '';
          destination = "secrets/secret-key";
          changeMode = "restart";
          splay = "15m";
        }
        genesisJson
      ];

      serviceName = "${namespace}-mantis-miner";

      tags = [ namespace name ];

      serverMeta = {
        ingressHost = "${namespace}-${name}.mantis.ws";
        ingressPort = toString publicServerPort;
        ingressBind = "*:${toString publicServerPort}";
        ingressMode = "tcp";
        ingressServer = "_${namespace}-mantis-miner._${name}.service.consul";
      };

      discoveryMeta = {
        ingressHost = "${namespace}-${name}.mantis.ws";
        ingressPort = toString publicDiscoveryPort;
        ingressBind = "*:${toString publicDiscoveryPort}";
        ingressMode = "tcp";
        ingressServer =
          "_${namespace}-mantis-miner._${name}-discovery.service.consul";
      };
    });

  mkPassive = count:
    let name = "${namespace}-mantis-passive";
    in mkMantis {
      inherit name;
      serviceName = name;
      resources = {
        # For c5.2xlarge in clusters/mantis/testnet/default.nix, the url ref below
        # provides 3.4 GHz * 8 vCPU = 27.2 GHz max.  80% is 21760 MHz.
        # Allocating by vCPU or core quantity not yet available.
        # Ref: https://github.com/hashicorp/nomad/blob/master/client/fingerprint/env_aws.go
        cpu = 500;
        memoryMB = 5 * 1024;
      };

      tags = [ namespace "passive" ];

      inherit count;

      requiredPeerCount = builtins.length miners;

      services."${name}-rpc" = {
        addressMode = "host";
        tags = [ "rpc" namespace name mantis-source.rev ];
        portLabel = "rpc";
      };

      templates = [
        {
          data = ''
            include "${mantis}/conf/testnet-internal-nomad.conf"

            logging.json-output = true
            logging.logs-file = "logs"

            mantis.blockchains.testnet-internal-nomad.bootstrap-nodes = [
              {{ range service "${namespace}-mantis-miner-server" -}}
                "enode://  {{- with secret (printf "kv/data/nomad-cluster/${namespace}/%s/enode-hash" .ServiceMeta.Name) -}}
                  {{- .Data.data.value -}}
                  {{- end -}}@{{ .Address }}:{{ .Port }}",
              {{ end -}}
            ]

            mantis.blockchains.testnet-internal-nomad.checkpoint-public-keys = [
              ${
                lib.concatMapStringsSep "," (x: ''
                  {{- with secret "kv/data/nomad-cluster/${namespace}/obft-node-${
                    toString x
                  }/obft-public-key" -}}"{{- .Data.data.value -}}"{{end}}
                '') (lib.range 1 amountOfMorphoNodes)
              }
            ]

            mantis.client-id = "${name}"
            mantis.consensus.mining-enabled = false
            mantis.datadir = "/local/mantis"
            mantis.ethash.ethash-dir = "/local/ethash"
            mantis.metrics.enabled = true
            mantis.metrics.port = {{ env "NOMAD_PORT_metrics" }}
            mantis.network.rpc.http.interface = "0.0.0.0"
            mantis.network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}
            mantis.network.server-address.port = {{ env "NOMAD_PORT_server" }}
            mantis.blockchains.testnet-internal-nomad.custom-genesis-file = "{{ env "NOMAD_TASK_DIR" }}/genesis.json"

            mantis.blockchains.testnet-internal-nomad.ecip1098-block-number = 0
            mantis.blockchains.testnet-internal-nomad.ecip1097-block-number = 0
          '';
          changeMode = "noop";
          destination = "local/mantis.conf";
          splay = "15m";
        }
        genesisJson
      ];
    };

  amountOfMiners = 5;

  miners = lib.forEach (lib.range 1 amountOfMiners) (num: {
    name = "mantis-${toString num}";
    requiredPeerCount = builtins.length miners;
    publicServerPort = 9000 + num; # routed through haproxy/ingress
    publicDiscoveryPort = 9500 + num; # routed through haproxy/ingress
  });

  explorer = let name = "${namespace}-explorer";
  in {
    services."${name}" = {
      addressMode = "host";
      portLabel = "explorer";

      tags = [ namespace "explorer" name ];

      meta = {
        inherit name;
        publicIp = "\${attr.unique.platform.aws.public-ipv4}";
        ingressHost = "${name}.mantis.ws";
        ingressMode = "http";
        ingressBind = "*:443";
        ingressServer = "_${name}._tcp.service.consul";
        ingressBackendExtra = ''
          http-response set-header X-Server %s
        '';
      };

      checks = [{
        type = "http";
        path = "/";
        portLabel = "explorer";

        checkRestart = {
          limit = 5;
          grace = "300s";
          ignoreWarnings = false;
        };
      }];
    };

    networks = [{
      mode = "bridge";
      ports = { explorer.to = 8080; };
    }];

    tasks.explorer = {
      inherit name;
      driver = "docker";

      resources = {
        cpu = 100; # mhz
        memoryMB = 128;
      };

      config = {
        image = dockerImages.mantis-explorer-server;
        args = [ "nginx" "-c" "/local/nginx.conf" ];
        ports = [ "explorer" ];
        labels = [{
          inherit namespace name;
          imageTag = dockerImages.mantis-explorer-server.image.imageTag;
        }];

        logging = {
          type = "journald";
          config = [{
            tag = name;
            labels = "name,namespace,imageTag";
          }];
        };
      };

      templates = [{
        data = ''
          user nginx nginx;
          error_log /dev/stderr info;
          pid /dev/null;
          events {}
          daemon off;

          http {
            access_log /dev/stdout;

            upstream backend {
              least_conn;
              {{ range service "${namespace}-mantis-passive-rpc" }}
                server {{ .Address }}:{{ .Port }};
              {{ end }}
            }

            server {
              listen 8080;

              location / {
                root /mantis-explorer;
                index index.html;
                try_files $uri $uri/ /index.html;
              }

              location /rpc/node {
                proxy_pass http://backend/;
              }

              location /sockjs-node {
                proxy_pass http://backend/;
              }
            }
          }
        '';
        changeMode = "restart";
        destination = "local/nginx.conf";
      }];
    };
  };

  faucetName = "${namespace}-faucet";
  faucet = {
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

        tags = [ namespace "faucet" faucetName mantis-faucet-source.rev ];

        meta = {
          name = faucetName;
          publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          ingressHost = "${faucetName}.mantis.ws";
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
        tags = [ namespace "faucet" faucetName mantis-faucet-source.rev ];
        meta = {
          name = faucetName;
          publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          ingressHost = "${faucetName}-web.mantis.ws";
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
              json-output = true

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
  };

  updateOneAtATime = {
    maxParallel = 1;
    # healthCheck = "checks"
    minHealthyTime = "30s";
    healthyDeadline = "10m";
    progressDeadline = "20m";
    autoRevert = false;
    autoPromote = false;
    canary = 0;
    stagger = "1m";
  };
in {
  "${namespace}-mantis" = mkNomadJob "mantis" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    update = updateOneAtATime;

    taskGroups = let
      minerTaskGroups = lib.listToAttrs (map mkMiner miners);
      passiveTaskGroups = { passive = mkPassive 3; };
    in minerTaskGroups // passiveTaskGroups;
  };

  "${namespace}-morpho" = mkNomadJob "morpho" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    update = updateOneAtATime;

    taskGroups = let
      mkMorpho = import ./tasks/morpho.nix;
      generateMorphoTaskGroup = nbNodes: node:
        lib.nameValuePair node.name (lib.recursiveUpdate (mkPassive 1)
          (mkMorpho (node // { inherit nbNodes; })));
      morphoTaskGroups =
        map (generateMorphoTaskGroup (builtins.length morphoNodes)) morphoNodes;
    in lib.listToAttrs morphoTaskGroups;
  };

  "${namespace}-explorer" = mkNomadJob "explorer" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    taskGroups.explorer = explorer;
  };

  "${namespace}-faucet" = mkNomadJob "faucet" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    taskGroups.faucet = faucet;
  };

  "${namespace}-backup" = mkNomadJob "backup" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "batch";
    inherit namespace;

    periodic = {
      cron = "15 */1 * * * *";
      prohibitOverlap = true;
      timeZone = "UTC";
    };

    taskGroups.backup = import ./tasks/backup.nix {
      inherit lib dockerImages namespace mantis;
      name = "${namespace}-backup";
    };
  };
}
