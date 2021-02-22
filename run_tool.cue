command: images: {
	build: exec.Run & {
		cmd:    "nix build -o docker_images.cue .#dockerImagesCue"
		stdout: string
	}
}
