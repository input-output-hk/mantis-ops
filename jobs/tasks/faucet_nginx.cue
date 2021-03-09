package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
)

#FaucetNginx: types.#stanza.task & {
	#taskArgs: {
		upstreamServiceName: string
		mantisOpsRev:        string
	}

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	driver: "exec"

	config: {
		flake: "github:input-output-hk/mantis-ops?rev=\(#taskArgs.mantisOpsRev)#mantis-faucet-nginx"
		args: ["/local/nginx.conf"]
		command: "/bin/entrypoint"
	}

	template: "local/nginx.conf": {
		change_mode: "restart"
		data:        """
    error_log /dev/stderr info;
    pid /dev/null;
    events {}
    daemon off;

    http {
      access_log /dev/stdout;

      upstream backend {
        least_conn;
        {{ range service "\(#taskArgs.upstreamServiceName)" }}
          server {{ .Address }}:{{ .Port }};
        {{ end }}
      }

      server {
        listen {{ env "NOMAD_PORT_nginx" }};

        location / {
          root /mantis-faucet;
          index index.html;
          try_files $uri $uri/ /index.html;
        }

        location /rpc/node {
          proxy_pass http://backend;
        }
      }
    }
    """
	}
}
