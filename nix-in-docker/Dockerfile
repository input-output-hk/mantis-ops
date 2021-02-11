FROM nixpkgs/nix-unstable

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs && \
    nix-channel --update && \
    nix-env -i git

VOLUME ["/nix", "/root"]

COPY nix.conf /etc/nix/nix.conf

CMD nix-shell
