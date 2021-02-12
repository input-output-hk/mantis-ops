{
  description = "Bitte for Mantis";

  inputs = {
    bitte-cli.follows = "bitte/bitte-cli";
    # bitte.url = "github:input-output-hk/bitte";
    bitte.url = "path:/home/craige/source/IOHK/bitte";
    # bitte.url = "path:/home/jlotoski/work/iohk/bitte-wt/bitte";
    # bitte.url = "path:/home/manveru/github/input-output-hk/bitte";
    nixpkgs.follows = "bitte/nixpkgs";
    terranix.follows = "bitte/terranix";
    utils.url = "github:numtide/flake-utils";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
    inclusive.follows = "bitte/inclusive";
    morpho-node.url = "github:input-output-hk/ECIP-Checkpointing/master";
    mantis-explorer.url = "github:input-output-hk/mantis-explorer/kevm";
    mantis-faucet-web.url =
      "github:input-output-hk/mantis-faucet-web/nix-build";
  };

  outputs = { self, nixpkgs, utils, ops-lib, bitte, ... }@inputs:
    let
      mantisKevmOverlay = import ./overlay.nix inputs;
      bitteOverlay = bitte.overlay.x86_64-linux;

      hashiStack = bitte.mkHashiStack {
        flake = self;
        rootDir = ./.;
        inherit pkgs;
        domain = "portal.dev.cardano.org";
      };

      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [
          (final: prev: { inherit (hashiStack) clusters dockerImages; })
          bitteOverlay
          mantisKevmOverlay
        ];
      };
    in {
      inherit self;
      inherit (hashiStack) nomadJobs dockerImages clusters nixosConfigurations;
      inherit (pkgs) sources;
      legacyPackages.x86_64-linux = pkgs;
      devShell.x86_64-linux = pkgs.devShell;
    };
}
