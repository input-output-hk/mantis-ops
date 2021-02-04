{
  description = "Bitte for Mantis";

  inputs = {
    # bitte.url = "github:input-output-hk/bitte/trim";
    bitte.url = "/Users/kreisys/Werk/iohk/bitte";
    bitte.inputs.cli.url = "/Users/kreisys/Werk/iohk/bitte-cli";
    utils.url = "github:kreisys/flake-utils";
    morpho-node.url = "github:input-output-hk/ECIP-Checkpointing/flake-refresh";
    mantis-explorer.url = "github:input-output-hk/mantis-explorer/flake-refresh";
    mantis-faucet-web.url =
      "github:input-output-hk/mantis-faucet-web/flake-refresh";
  };

  outputs = { self, mantis-explorer, morpho-node, mantis-faucet-web, nixpkgs, utils, bitte, ... }:
    let
      simpleFlake = utils.lib.simpleFlake
        {
          inherit nixpkgs;
          name = "mantis-ops";
          systems = [ "x86_64-darwin" "x86_64-linux" ];

          config.allowUnfreePredicate = pkg:
            let name = nixpkgs.lib.getName pkg;
            in
            (builtins.elem name [ "ssm-session-manager-plugin" ])
            || throw "unfree not allowed: ${name}";

          overlays = [
            bitte
            mantis-explorer
            mantis-faucet-web
            morpho-node
            ./overlay.nix
            (final: prev: {
              morpho-source = morpho-node;
            })
          ];

          packages = { generate-mantis-keys }: {
            inherit generate-mantis-keys;
          };

          shell = { mkBitteShell }: mkBitteShell {
            profile = "mantis";
            cluster = "mantispw-testnet";
            nixConf = ./nix.conf;
            inherit self;
          };
        };

        hashiStack = bitte.lib.mkHashiStack {
          inherit self;
          rootDir = ./.;
          domain = "mantis.pw";
        };
    in
    simpleFlake // {
      inherit (hashiStack) nomadJobs dockerImages clusters;
      nixosConfigurations = hashiStack.nixosConfigurations // bitte.nixosConfigurations;
    };
}
