package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
)

#Explorer: types.#stanza.task & {
	#taskArgs: {
		upstreamServiceName: string
		mantisOpsRev:        string
	}

	driver: "exec"

	config: {
		flake: "github:input-output-hk/mantis-ops?rev=\(#taskArgs.mantisOpsRev)#mantis-faucet-nginx"
		args: ["-c", "/local/nginx.conf"]
		command: "/bin/entrypoint"
	}

	template: "local/nginx.conf": {
		change_mode: "restart"
		data:        """
    user nobody nogroup;
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
        listen {{ env "NOMAD_PORT_explorer" }};

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
    """
	}
}
