FROM nixos/nix

RUN apk --update add git less openssh && \
    rm -rf /var/lib/apt/lists/* && \
    rm /var/cache/apk/*

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
RUN nix-channel --update

RUN nix-build -A pythonFull '<nixpkgs>'

RUN nix-shell --run ' \
     ( nix build .#nixFlakes -o devShell \
       nix-env -i ./devShell \
       rm devShell \
     ) || nix profile install github:input-output-hk/mantis-ops#nixFlakes \
     '

ENTRYPOINT nix-shell
