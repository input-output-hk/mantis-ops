{
  description = "Bitte for Mantis";

  inputs = {
    bitte.url = "github:input-output-hk/bitte";
    nixpkgs.follows = "bitte/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    terranix.follows = "bitte/terranix";
    utils.follows = "bitte/utils";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
    inclusive.follows = "bitte/inclusive";
    morpho-node.url = "github:input-output-hk/ECIP-Checkpointing";
    mantis.url =
      "github:input-output-hk/mantis?rev=2cce0ba56ea6b880704fd601b37508cc9a302f33";
    mantis-explorer.url = "github:input-output-hk/mantis-explorer";
    mantis-faucet-web.url = "github:input-output-hk/mantis-faucet-web";
  };

  outputs = { self, nixpkgs, utils, ops-lib, bitte, ... }@inputs:
    let
      hashiStack = bitte.mkHashiStack {
        flake = self;
        rootDir = ./.;
        inherit pkgs;
        domain = "mantis.ws";
      };

      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [
          (final: prev: { inherit (hashiStack) clusters dockerImages; })
          bitte.overlay.x86_64-linux
          (import ./overlay.nix inputs)
        ];
      };

      nixosConfigurations = hashiStack.nixosConfigurations;
    in {
      inherit nixosConfigurations;
      clusters.x86_64-linux = hashiStack.clusters;
      legacyPackages.x86_64-linux = pkgs;
      devShell.x86_64-linux = pkgs.devShell;
      hydraJobs.x86_64-linux = {
        inherit (pkgs)
          bitte cfssl consul cue devShellPath grafana grafana-loki haproxy
          nixFlakes nomad sops terraform-with-plugins vault-bin victoriametrics

          generate-mantis-keys

          mantis mantis-staging

          mantis-faucet-web mantis-faucet-nginx mantis-faucet-server

          mantis-explorer mantis-explorer-nginx

          morpho-node

        ;
      } // (pkgs.lib.mapAttrs (_: v: v.config.system.build.toplevel)
        nixosConfigurations);
    };
}
