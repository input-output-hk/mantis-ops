{ namespace, name, nodeNumber, morpho-source, vault, dockerImages, nbNodes }: {
  services = {
    "${namespace}-morpho-node" = {
      portLabel = "morpho";

      tags = [ "morpho" namespace name morpho-source.rev ];
      meta = {
        inherit name;
        nodeNumber = builtins.toString nodeNumber;
      };
    };
  };

  ephemeralDisk = {
    sizeMB = 500;
    migrate = true;
    sticky = true;
  };

  networks = [{
    mode = "bridge";
    ports = {
      discovery.to = 6000;
      metrics.to = 6100;
      rpc.to = 6200;
      server.to = 6300;
      morpho.to = 6400;
      morphoPrometheus.to = 6500;
    };
  }];

  tasks.${name} = {
    inherit name vault;
    driver = "docker";
    env = { REQUIRED_PEER_COUNT = builtins.toString nbNodes; };

    resources = {
      cpu = 100; # mhz
      memoryMB = 1024;
    };

    templates = [
      {
        data = ''
          ApplicationName: morpho-checkpoint
          ApplicationVersion: 1
          CheckpointInterval: 4
          FedPubKeys: [
          {{ range secrets "kv/metadata/nomad-cluster/${namespace}/" -}}
            {{- if . | contains "obft" -}}
                "{{- with secret (printf "kv/data/nomad-cluster/${namespace}/%s/obft-public-key" . ) -}}{{ .Data.data.value }}{{end}}",
            {{ end }}
          {{- end -}}
          ]
          LastKnownBlockVersion-Major: 0
          LastKnownBlockVersion-Minor: 2
          LastKnownBlockVersion-Alt: 0
          NetworkMagic: 12345
          NodeId: {{ index (split "-" "${name}") 2 }}
          NodePrivKeyFile: {{ env "NOMAD_SECRETS_DIR" }}/morpho-private-key
          NumCoreNodes: ${toString nbNodes}
          PoWBlockFetchInterval: 5000000
          PoWNodeRpcUrl: http://127.0.0.1:{{ env "NOMAD_PORT_rpc" }}
          PrometheusPort: {{ env "NOMAD_PORT_morphoPrometheus" }}
          Protocol: MockedBFT
          RequiredMajority: ${toString ((nbNodes / 2) + 1)}
          RequiresNetworkMagic: RequiresMagic
          SecurityParam: 2200
          StableLedgerDepth: 6
          SlotDuration: 5
          SnapshotsOnDisk: 60
          SnapshotInterval: 60
          SystemStart: "2020-11-17T00:00:00Z"
          TurnOnLogMetrics: True
          TurnOnLogging: True
          ViewMode: SimpleView
          minSeverity: Debug
          TracingVerbosity: NormalVerbosity
          setupScribes:
            - scKind: StdoutSK
              scFormat: ScText
              scName: stdout
          defaultScribes:
            - - StdoutSK
              - stdout
          setupBackends:
            - KatipBK
          defaultBackends:
            - KatipBK
          options:
            mapBackends:
        '';
        destination = "local/morpho-config.yaml";
        changeMode = "noop";
        splay = "15m";
      }
      {
        data = ''
          {{- with secret "kv/data/nomad-cluster/${namespace}/${name}/obft-secret-key" -}}
          {{- .Data.data.value -}}
          {{- end -}}
        '';
        destination = "secrets/morpho-private-key";
        changeMode = "restart";
        splay = "15m";
      }
      {
        data =
          let
            addressFor = n: {
              addr = "_mantis-staging-morpho-node._obft-node-${toString n}.service.consul";
              # No port -> SRV query above address
              valency = 1;
            };
            producers = map addressFor (lib.range 1 5);
            data = map (n: {
              nodeAddress = addressFor n;
              nodeId = n;
              inherit producers;
            }) (lib.range 1 5);
          in builtins.toJSON data;
        destination = "local/morpho-topology.json";
      }
    ];

    config = {
      image = dockerImages.morpho;
      args = [ ];
      labels = [{
        inherit namespace name;
        imageTag = dockerImages.morpho.image.imageTag;
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
      interval = "10m";
      attempts = 10;
      delay = "30s";
      mode = "delay";
    };
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

        urls = [
          "http://127.0.0.1:{{ env "NOMAD_PORT_morphoPrometheus" }}"
        ]

        [outputs.influxdb]
        database = "telegraf"
        urls = [ {{ with node "monitoring" }}"http://{{ .Node.Address }}:8428"{{ end }} ]
      '';

      destination = "local/telegraf.config";
    }];
  };

  tasks.telegraf-morpho = {
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
          tag = "${name}-telegraf-morpho";
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
        client_id = "${name}-mantis"
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
}
