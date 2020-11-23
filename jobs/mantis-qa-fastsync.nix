{ mkNomadJob, lib, mantis, mantis-source, dockerImages }:
let
  # NOTE: Copy this file and change the next line if you want to start your own cluster!
  namespace = "mantis-qa-fastsync";

  templatesFor = { name ? null, mining-enabled ? false }:
    let secret = key: ''{{ with secret "${key}" }}{{.Data.data.value}}{{end}}'';
    in [{
      data = ''
        include "${mantis}/conf/etc.conf"

        logging.json-output = true
        logging.logs-file = "logs"

        mantis.client-id = "${name}"
        mantis.sync.do-fast-sync = true
        mantis.consensus.coinbase = "{{ with secret "kv/data/nomad-cluster/${namespace}/${name}/coinbase" }}{{ .Data.data.value }}{{ end }}"
        mantis.node-key-file = "{{ env "NOMAD_SECRETS_DIR" }}/secret-key"
        mantis.datadir = "/local/mantis"
        mantis.ethash.ethash-dir = "/local/ethash"
        mantis.metrics.enabled = true
        mantis.metrics.port = {{ env "NOMAD_PORT_metrics" }}
        mantis.network.rpc.http.interface = "0.0.0.0"
        mantis.network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}
        mantis.network.server-address.port = {{ env "NOMAD_PORT_server" }}
      '';
      destination = "local/mantis.conf";
      changeMode = "noop";
    }] ++ (lib.optional mining-enabled {
      data = ''
        ${secret "kv/data/nomad-cluster/${namespace}/${name}/secret-key"}
        ${secret "kv/data/nomad-cluster/${namespace}/${name}/enode-hash"}
      '';
      destination = "secrets/secret-key";
    });

  mkMantis = { name, resources, count ? 1, templates, serviceName, tags ? [ ]
    , meta ? { }, constraints ? [ ], requiredPeerCount, services ? { } }: {
      inherit count constraints;

      networks = [{
        ports = {
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

        vault.policies = [ "nomad-cluster" ];

        resources = {
          cpu = 100; # mhz
          memoryMB = 128;
        };

        config = {
          image = dockerImages.telegraf.id;
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

            urls = [ "http://{{ env "NOMAD_ADDR_metrics" }}" ]

            [outputs.influxdb]
            database = "telegraf"
            urls = ["http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428"]
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

        ${serviceName} = {
          addressMode = "host";
          portLabel = "server";

          tags = [ "server" namespace serviceName mantis-source.rev ] ++ tags;

          meta = {
            inherit name;
            publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          } // meta;

          checks = [{
            type = "http";
            path = "/healthcheck";
            portLabel = "rpc";

            checkRestart = {
              limit = 5;
              grace = "300s";
              ignoreWarnings = false;
            };
          }];
        };
      } services;

      tasks.${name} = {
        inherit name resources templates;
        driver = "docker";
        vault.policies = [ "nomad-cluster" ];

        config = {
          image = dockerImages.mantis.id;
          args = [ "-Dconfig.file=running.conf" ];
          ports = [ "rpc" "server" "metrics" ];
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

  mkMiner = { name, publicPort, requiredPeerCount ? 0, instanceId ? null }:
    lib.nameValuePair name (mkMantis {
      resources = {
        # For c5.2xlarge in clusters/mantis/testnet/default.nix, the url ref below
        # provides 3.4 GHz * 8 vCPU = 27.2 GHz max.  80% is 21760 MHz.
        # Allocating by vCPU or core quantity not yet available.
        # Ref: https://github.com/hashicorp/nomad/blob/master/client/fingerprint/env_aws.go
        cpu = 21760;
        memoryMB = 4 * 1024;
      };

      inherit name requiredPeerCount;
      templates = templatesFor {
        inherit name;
        mining-enabled = true;
      };

      serviceName = "${namespace}-mantis-miner";

      tags = [ "ingress" namespace name ];

      meta = {
        ingressHost = "${name}.mantis.ws";
        ingressPort = toString publicPort;
        ingressBind = "*:${toString publicPort}";
        ingressMode = "tcp";
        ingressServer = "${name}.${namespace}-mantis-miner.service.consul";
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
        memoryMB = 3 * 1024;
      };

      tags = [ namespace "passive" "ingress" ];

      inherit count;

      requiredPeerCount = builtins.length miners;

      services."${name}-rpc" = {
        addressMode = "host";
        tags = [ "rpc" "ingress" namespace name mantis-source.rev ];
        portLabel = "rpc";
        meta = {
          ingressHost = "${namespace}-explorer.mantis.ws";
          ingressMode = "http";
          ingressBind = "*:443";
          ingressIf = "{ path_beg -i /rpc/node }";
          ingressServer = "_${name}-rpc._tcp.service.consul";
          ingressBackendExtra = ''
            option tcplog
            http-request set-path /
          '';
        };
      };

      templates = [{
        data = ''
          include "${mantis}/conf/etc.conf"

          logging.json-output = true
          logging.logs-file = "logs"

          mantis.client-id = "${name}"
          mantis.sync.do-fast-sync = true
          mantis.consensus.mining-enabled = false
          mantis.datadir = "/local/mantis"
          mantis.ethash.ethash-dir = "/local/ethash"
          mantis.metrics.enabled = true
          mantis.metrics.port = {{ env "NOMAD_PORT_metrics" }}
          mantis.network.rpc.http.interface = "0.0.0.0"
          mantis.network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}
          mantis.network.server-address.port = {{ env "NOMAD_PORT_server" }}
        '';
        changeMode = "restart";
        destination = "local/mantis.conf";
      }];
    };

  amountOfMiners = 0;

  miners = lib.forEach (lib.range 1 amountOfMiners) (num: {
    name = "mantis-${toString num}";
    requiredPeerCount = num - 1;
    publicPort = 9000 + num; # routed through haproxy/ingress
  });
in {
  "${namespace}-mantis" = mkNomadJob "mantis" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    update = {
      maxParallel = 1;
      # healthCheck = "checks"
      minHealthyTime = "30s";
      healthyDeadline = "5m";
      progressDeadline = "10m";
      autoRevert = true;
      autoPromote = true;
      canary = 1;
      stagger = "30s";
    };

    taskGroups = (lib.listToAttrs (map mkMiner miners)) // {
      passive = mkPassive 3;
    };
  };
}

// (import ./mantis-active-gen.nix {
  inherit mkNomadJob dockerImages;
  namespace = "mantis-qa-fastsync";
})
