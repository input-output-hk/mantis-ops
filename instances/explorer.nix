{ namespace, domain, dockerImages }:

let
  name = "${namespace}-explorer";
in {
  services."${name}" = {
    addressMode = "host";
    portLabel = "explorer";

    tags = [ "ingress" namespace "explorer" name ];

    meta = {
      inherit name;
      publicIp = "\${attr.unique.platform.aws.public-ipv4}";
      ingressHost = "explorer.${domain}";
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
}


