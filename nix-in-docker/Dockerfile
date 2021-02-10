FROM nixos/nix

VOLUME /nix
VOLUME /root

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
RUN nix-channel --update
RUN nix-env -i git

COPY nix.conf /etc/nix/nix.conf

CMD nix-shell
