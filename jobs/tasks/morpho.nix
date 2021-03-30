{ lib, namespace, name, nodeNumber, nodeCount, morpho-source, vault, dockerImages, nbNodes }: {
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
    # From https://github.com/input-output-hk/bitte/blob/33cb20fa1cd7c6e4d3bc75253fc166bf048b500c/profiles/docker.nix#L16
    dns.servers = [ "172.17.0.1" ];
    ports = {
      discovery.to = 6000;
      metrics.to = 6100;
      rpc.to = 6200;
      server.to = 6300;
      morpho.to = 6400;
      morphoPrometheus.to = 6500;
    };
  }];

  tasks.morpho = {
    inherit vault;
    driver = "docker";

    resources = {
      cpu = 100; # mhz
      memoryMB = 1024;
    };

    templates = [
      {
        data = ''
          CheckpointInterval: 4
          FedPubKeys: [
          {{ range secrets "kv/metadata/nomad-cluster/${namespace}/" -}}
            {{- if . | contains "obft" -}}
                "{{- with secret (printf "kv/data/nomad-cluster/${namespace}/%s/obft-public-key" . ) -}}{{ .Data.data.value }}{{end}}",
            {{ end }}
          {{- end -}}
          ]
          NetworkMagic: 12345
          NodeId: ${toString nodeNumber}
          NodePort: {{ env "NOMAD_PORT_morpho" }}
          DatabaseDirectory: /local/db
          TopologyFile: {{ env "NOMAD_TASK_DIR" }}/morpho-topology.json
          NodePrivKeyFile: {{ env "NOMAD_SECRETS_DIR" }}/morpho-private-key
          NumCoreNodes: ${toString nbNodes}
          PoWBlockFetchInterval: 5000000
          PoWNodeRpcUrl: http://127.0.0.1:{{ env "NOMAD_PORT_rpc" }}
          PrometheusPort: {{ env "NOMAD_PORT_morphoPrometheus" }}
          Protocol: MockedBFT
          RequiredMajority: ${toString ((nbNodes / 2) + 1)}
          SecurityParam: 2200
          StableLedgerDepth: 6
          SlotDuration: 5
          SystemStart: "2020-11-17T00:00:00Z"
          TurnOnLogging: True
          Logging:
            minSeverity: Info
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
              addr = "_${namespace}-morpho-node._obft-node-${toString n}.service.consul.";
              # No port -> SRV query above address
              valency = 1;
            };
            data = map (n: {
              nodeId = n;
              producers = map addressFor (lib.remove n (lib.range 1 nodeCount));
            }) (lib.range 1 nodeCount);
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
}
