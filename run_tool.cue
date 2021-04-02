package bitte

import (
	"encoding/json"
	"tool/cli"
	"tool/exec"
)

#jobName:   string @tag(job)
#namespace: string @tag(namespace)

command: render: {
	display: cli.Print & {
		text: json.Indent(json.Marshal(
			rendered[#namespace][#jobName],
			), "", "  ")
	}
}

command: images: {
	build: exec.Run & {
		cmd:    "nix build -o docker_images.cue .#dockerImagesCue"
		stdout: string
	}
}
