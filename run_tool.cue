package bitte

import (
	"encoding/json"
	"tool/cli"
	"tool/os"
	"tool/exec"
	"tool/http"
	"strings"
)

#jobName: string @tag(job)

command: render: {
	environment: os.Environ & {
		NOMAD_NAMESPACE: string
	}

	display: cli.Print & {
		text: json.Indent(json.Marshal(
			rendered[environment.NOMAD_NAMESPACE][#jobName],
			), "", "  ")
	}
}

command: run: {
	environment: os.Environ & {
		NOMAD_NAMESPACE:   =~"^mantis-.+"
		CONSUL_HTTP_TOKEN: =~"^\\d+$"
		NOMAD_ADDR:        =~"^https://nomad\\..+$"
		NOMAD_TOKEN:       =~"^\\d+$"
	}

	vault_token: exec.Run & {
		cmd:    "vault print token"
		stdout: string
	}

	curl: http.Post & {
		url: "\(environment.NOMAD_ADDR)/v1/jobs"
		request: {
			header: {
				"X-Nomad-Token": environment.NOMAD_TOKEN
				"X-Vault-Token": strings.TrimSpace(vault_token.stdout)
			}
			body: json.Marshal(rendered[environment.NOMAD_NAMESPACE][#jobName] & {
				Job: ConsulToken: environment.CONSUL_HTTP_TOKEN
			})
		}
	}

	result: cli.Print & {
		text: json.Indent(json.Marshal(curl.response.body), "", "  ")
	}
}

command: plan: {
	environment: os.Environ & {
		NOMAD_NAMESPACE:   string
		CONSUL_HTTP_TOKEN: string
		NOMAD_ADDR:        string
		NOMAD_TOKEN:       string
	}

	vault_token: exec.Run & {
		cmd:    "vault print token"
		stdout: string
	}

	curl: http.Post & {
		_job: rendered[environment.NOMAD_NAMESPACE][#jobName] & {
			Job: ConsulToken: environment.CONSUL_HTTP_TOKEN
			Diff:           true
			PolicyOverride: false
		}
		url: "\(environment.NOMAD_ADDR)/v1/job/\(_job.Job.ID)/plan"
		request: {
			header: {
				"X-Nomad-Token": environment.NOMAD_TOKEN
				"X-Vault-Token": strings.TrimSpace(vault_token.stdout)
			}
			body: json.Marshal(_job)
		}
	}

	result: cli.Print & {
		_response: curl.response
		_body:     json.Unmarshal(_response.body)
		text:      """
    body: \(json.Indent(_response.body, "", "  "))
    trailer: \(json.Indent(json.Marshal(_response.trailer), "", "  "))
    """
	}
}

command: images: {
	build: exec.Run & {
		cmd:    "nix build -o docker_images.cue .#dockerImagesCue"
		stdout: string
	}
}
