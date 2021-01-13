default: secrets/nix-public-key-file
.PHONY: default

secrets:
	mkdir -p $@

secrets/nix-public-key-file: secrets/nix-secret-key-file

secrets/nix-secret-key-file: secrets
	nix-store --generate-binary-cache-key "$$BITTE_CLUSTER-0" $@ secrets/nix-public-key-file

encrypted/nix-public-key-file: secrets/nix-public-key-file
	cp $< $@
