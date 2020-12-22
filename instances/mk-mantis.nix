{ dockerImages
, mantis-source
, vault
}:

{ name
, lib
, resources
, namespace
, count ? 1
, templates
, serviceName
, tags ? [ ]
, serverMeta ? { }
, meta ? { }
, discoveryMeta ? { }
, rpcMeta ? { }
, requiredPeerCount
, services ? { }
}:

{
  inherit count;

  networks = [{
    mode = "bridge";
    ports = {
      discovery.to = 2000;
      metrics.to = 3000;
      rpc.to = 4000;
      server.to = 5000;
      vm.to = 6000;
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
      tags = [ "rpc" namespace serviceName name mantis-source.rev ] ++ tags;
      meta = {
        inherit name;
        publicIp = "\${attr.unique.platform.aws.public-ipv4}";
      } // rpcMeta;
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
      image = dockerImages.mantis-kevm;
      args = [ "-Dconfig.file=running.conf" ];
      ports = [ "rpc" "server" "metrics" "vm" ];
      labels = [{
        inherit namespace name;
        imageTag = dockerImages.mantis-kevm.image.imageTag;
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
}

