{
  description = "Bitte for Mantis";

  inputs = {
    bitte.url = "github:input-output-hk/bitte/trim";
    # bitte.url = "/Users/kreisys/Werk/iohk/bitte";
    bitte.inputs.cli.url = "github:input-output-hk/bitte-cli/updates";
    # bitte.inputs.cli.url = "/Users/kreisys/Werk/iohk/bitte-cli";
    utils.url = "github:kreisys/flake-utils";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
    morpho-node.url = "github:input-output-hk/ECIP-Checkpointing/flake-refresh";
    # morpho-node.url = "/Users/kreisys/Werk/iohk/ECIP-Checkpointing";
    mantis-explorer.url = "github:input-output-hk/mantis-explorer/flake-refresh";
    # mantis-explorer.url = "/Users/kreisys/Werk/iohk/mantis-explorer";
    mantis-faucet-web.url =
      "github:input-output-hk/mantis-faucet-web/flake-refresh";
    # mantis-faucet-web.url =
    #   "/Users/kreisys/Werk/iohk/mantis-faucet-web";
  };

  outputs = { self, mantis-explorer, morpho-node, mantis-faucet-web, nixpkgs, utils, ops-lib, bitte, ... }:
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
      inherit (hashiStack) nomadJobs dockerImages clusters nixosConfigurations;
    #   clusters.x86_64-darwin = bitte.lib.mkClusters rec {
    #     root = ./clusters;
    #     system = "x86_64-darwin";
    #     inherit self nixpkgs;
    #   };

    #   clusters.x86_64-linux = bitte.lib.mkClusters rec {
    #     root = ./clusters;
    #     system = "x86_64-linux";
    #     inherit self nixpkgs;
    #   };

    #   nixosConfigurations =
    #     bitte.lib.mkNixosConfigurations
    #       self.clusters.x86_64-darwin;
    };
}

#       (utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" ] (system: rec {
#         overlay = import ./overlay.nix { inherit system self; };

#         legacyPackages = import nixpkgs {
#           inherit system;
#           config.allowUnfreePredicate = pkg:
#             let name = nixpkgs.lib.getName pkg;
#             in
#             (builtins.elem name [ "ssm-session-manager-plugin" ])
#             || throw "unfree not allowed: ${name}";
#           overlays = [ overlay ];
#         };

#         inherit (legacyPackages) devShell;

#         packages = {
#           inherit (legacyPackages)
#             bitte nixFlakes sops generate-mantis-keys terraform-with-plugins cfssl
#             consul;
#         };

#         hydraJobs = packages // {
#           prebuilt-devshell =
#             devShell.overrideAttrs (_: { nobuildPhase = "touch $out"; });
#         };

#         apps.bitte = utils.lib.mkApp { drv = legacyPackages.bitte; };
#       })) // (
#       let
#         pkgs = import nixpkgs {
#           overlays = [ self.overlay.x86_64-linux ];
#           system = "x86_64-linux";
#         };
#       in
#       {
#         inherit (pkgs) clusters nomadJobs dockerImages;
#         nixosConfigurations = pkgs.nixosConfigurations // {
#           # attrs of interest:
#           # * config.system.build.zfsImage
#           # * config.system.build.uploadAmi
#           zfs-ami = import "${nixpkgs}/nixos" {
#             configuration = { pkgs, lib, ... }: {
#               imports = [
#                 ops-lib.nixosModules.make-zfs-image
#                 ops-lib.nixosModules.zfs-runtime
#                 "${nixpkgs}/nixos/modules/profiles/headless.nix"
#                 "${nixpkgs}/nixos/modules/virtualisation/ec2-data.nix"
#               ];
#               nix.package = self.packages.x86_64-linux.nixFlakes;
#               nix.extraOptions = ''
#                 experimental-features = nix-command flakes
#               '';
#               systemd.services.amazon-shell-init.path = [ pkgs.sops ];
#               nixpkgs.config.allowUnfreePredicate = x:
#                 builtins.elem (lib.getName x) [ "ec2-ami-tools" "ec2-api-tools" ];
#               zfs.regions = [
#                 "eu-west-1"
#                 "ap-northeast-1"
#                 "ap-northeast-2"
#                 "eu-central-1"
#                 "us-east-2"
#               ];
#             };
#             system = "x86_64-linux";
#           };
#         };
#       }
#     );
# }
