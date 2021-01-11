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
    # This influences the ip in /etc/resolv.conf, but variable interpolation isn't available here
    # dns.servers = [ "\${attr.unique.network.ip-address}" ];
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
        changeMode = "signal";
        changeSignal = "SIGHUP";
      }
      {
        data = ''
          {{- with secret "kv/data/nomad-cluster/${namespace}/${name}/obft-secret-key" -}}
          {{- .Data.data.value -}}
          {{- end -}}
        '';
        destination = "secrets/morpho-private-key";
        # FIXME: [Why not] also signal?
        changeMode = "restart";
        splay = "15m";
      }
      {
        data = ''
          [
            {{- range $index1, $service1 := service "${namespace}-morpho-node" -}}
            {{ if ne $index1 0 }},{{ end }}
              {
                "nodeAddress": {
                "addr": "{{ .Address }}",
                "port": {{ .Port }},
                "valency": 1
                },
                "nodeId": {{- index (split "-" .ServiceMeta.Name) 2 -}},
                "producers": [
                {{- range $index2, $service2 := service "${namespace}-morpho-node" -}}
                {{ if ne $index2 0 }},{{ end }}
                  {
                      "addr": "{{ .Address }}",
                      "port": {{ .Port }},
                      "valency": 1
                  }
                {{- end -}}
                ]}
            {{- end }}
            ]
        '';
        destination = "local/morpho-topology.json";
        changeMode = "signal";
        changeSignal = "SIGHUP";
      }
    ];

    config = {
      image = dockerImages.morpho;
      # This doesn't appear to have any effect, despite
      # https://github.com/hashicorp/nomad/issues/3642#issuecomment-387490775 indicating it should work
      # dns_servers = [ "127.0.0.1" ];
      # dns_servers = [ "\${attr.unique.network.ip-address}" ];

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
