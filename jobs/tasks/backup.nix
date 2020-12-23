{ lib, dockerImages, namespace, name, mantis, config }: {
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

  tasks.backup = {
    driver = "docker";

    vault = {
      policies = [ "nomad-cluster" ];
      changeMode = "restart";
    };

    resources = {
      cpu = 500;
      memoryMB = 5 * 1024;
    };

    config = {
      image = dockerImages.backup;
      args = [ "--tag" namespace ];
      ports = [ "discovery" "metrics" "server" "rpc" "vm" ];

      labels = [{
        inherit namespace name;
        imageTag = dockerImages.backup.image.imageTag;
      }];

      logging = {
        type = "journald";
        config = [{
          tag = name;
          labels = "name,namespace,imageTag";
        }];
      };
    };

    templates = [
      {
        data = ''
          AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
          AWS_DEFAULT_REGION="us-east-1"
          AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
          RESTIC_PASSWORD="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.password}}{{end}}"
          RESTIC_REPOSITORY="s3:http://{{ with node "monitoring" }}{{ .Node.Address }}{{ end }}:9000/restic"
          MONITORING_URL="http://{{ with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428/api/v1/query"
        '';
        env = true;
        destination = "secrets/env.txt";
      }
      {
        data = config;
        changeMode = "noop";
        destination = "local/mantis.conf";
      }
      {
        data = ''
          {{- with secret "kv/nomad-cluster/${namespace}/genesis" -}}
          {{.Data.data | toJSON }}
          {{- end -}}
        '';
        destination = "local/genesis.json";
        changeMode = "noop";
      }
    ];
  };
}
