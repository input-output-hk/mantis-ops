{
  description = "Bitte for Mantis";

  inputs = {
    bitte.url = "github:input-output-hk/bitte/v21.12.10";
    # bitte.url = "github:input-output-hk/bitte/acme-terraform-remove-fix";
    # bitte.inputs.nixpkgs.follows = "nixpkgs";
    deploy.url = "github:input-output-hk/deploy-rs";
    deploy.inputs.utils.follows = "utils";
    nixpkgs.follows = "bitte/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    terranix.follows = "bitte/terranix";
    utils.follows = "bitte/utils";
    mantis.url = "github:input-output-hk/mantis/develop";
  };

  outputs = { self, nixpkgs, bitte, utils, ... }@inputs:
    let
      system = "x86_64-linux";

      overlay = final: prev: (nixpkgs.lib.composeManyExtensions overlays) final prev;
      overlays = [ (import ./overlay.nix inputs) bitte.overlay ];

      domain = "portal.dev.cardano.org";

      bitteStack =
        let stack = bitte.lib.mkBitteStack {
          inherit domain self inputs pkgs;
          clusters = "${self}/clusters";
          deploySshKey = "./secrets/ssh-mantis-kevm";
          hydrateModule = import ./hydrate.nix;
        };
        in
        stack // {
          deploy = stack.deploy // { autoRollback = false; };
        };

      pkgs = import nixpkgs {
        inherit overlays system;
        config.allowUnfree = true;
      };
    in
    {
      inherit overlay;

      legacyPackages.${system} = pkgs;

      devShell.${system} = let name = "mantis-kevm"; in
        pkgs.bitteShell {
          inherit self domain;
          profile = name;
          cluster = name;
          namespace = name;
          extraPackages = [ pkgs.cue ];
        };

    } // bitteStack;
}
