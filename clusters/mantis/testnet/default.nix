{ self, lib, pkgs, config, ... }:
let
  inherit (pkgs.terralib) sops2kms sops2region cidrsOf;
  inherit (builtins) readFile replaceStrings;
  inherit (lib) mapAttrs' nameValuePair flip attrValues listToAttrs forEach;
  inherit (config) cluster;
  inherit (import ./security-group-rules.nix { inherit config pkgs lib; })
    securityGroupRules;

  bitte = self.inputs.bitte;

  amis = {
    us-east-2 = "ami-0492aa69cf46f79c3";
    eu-central-1 = "ami-0839f2c610f876d2d";
  };

in {
  imports = [ ./iam.nix ];

  cluster = {
    name = "mantis-testnet";

    adminNames = [
      "john.lotoski"
      "michael.bishop"
      "michael.fellinger"
      "samuel.evans-powell"
      "samuel.leathers"
      "shay.bergmann"
    ];
    developerGithubNames = [ ];
    developerGithubTeamNames = [ "mantis-devs" ];
    domain = "mantis.ws";
    kms =
      "arn:aws:kms:eu-central-1:166923377823:key/745684e5-272e-49af-aad8-8b073b8d996a";
    s3Bucket = "iohk-mantis-bitte";
    terraformOrganization = "mantis";

    s3CachePubKey = lib.fileContents ../../../encrypted/nix-public-key-file;
    flakePath = ../../..;

    autoscalingGroups = listToAttrs (forEach [
      {
        region = "eu-central-1";
        desiredCapacity = 2;
      }
      {
        region = "us-east-2";
        desiredCapacity = 2;
      }
    ] (args:
      let
        extraConfig = pkgs.writeText "extra-config.nix" ''
          { lib, ... }:

          {
            disabledModules = [ "virtualisation/amazon-image.nix" ];
            networking = {
              hostId = "9474d585";
            };
            boot.initrd.postDeviceCommands = "echo FINDME; lsblk";
            boot.loader.grub.device = lib.mkForce "/dev/nvme0n1";
          }
        '';
        attrs = ({
          desiredCapacity = 1;
          instanceType = "c5.2xlarge";
          associatePublicIP = true;
          maxInstanceLifetime = 604800;
          iam.role = cluster.iam.roles.client;
          iam.instanceProfile.role = cluster.iam.roles.client;

          modules = [
            (bitte + /profiles/client.nix)
            self.inputs.ops-lib.nixosModules.zfs-runtime
            "${self.inputs.nixpkgs}/nixos/modules/profiles/headless.nix"
            "${self.inputs.nixpkgs}/nixos/modules/virtualisation/ec2-data.nix"
            "${extraConfig}"
            ./secrets.nix
            ./monitoring.nix
          ];

          securityGroupRules = {
            inherit (securityGroupRules)
              internet internal ssh mantis-rpc mantis-server;
          };
          ami = amis.${args.region};
          userData = ''
            # amazon-shell-init
            set -exuo pipefail

            ${pkgs.zfs}/bin/zpool online -e tank nvme0n1p3

            export CACHES="https://hydra.iohk.io https://cache.nixos.org ${cluster.s3Cache}"
            export CACHE_KEYS="hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= ${cluster.s3CachePubKey}"
            pushd /run/keys
            aws s3 cp "s3://${cluster.s3Bucket}/infra/secrets/${cluster.name}/${cluster.kms}/source/source.tar.xz" source.tar.xz
            mkdir -p source
            tar xvf source.tar.xz -C source
            nix build ./source#nixosConfigurations.${cluster.name}-${asgName}.config.system.build.toplevel --option substituters "$CACHES" --option trusted-public-keys "$CACHE_KEYS"
            /run/current-system/sw/bin/nixos-rebuild --flake ./source#${cluster.name}-${asgName} boot --option substituters "$CACHES" --option trusted-public-keys "$CACHE_KEYS"
            /run/current-system/sw/bin/shutdown -r now
          '';
        } // args);
        asgName = "client-${attrs.region}-${
            replaceStrings [ "." ] [ "-" ] attrs.instanceType
          }";
      in nameValuePair asgName attrs));

    instances = {
      core-1 = {
        instanceType = "t3a.medium";
        privateIP = "172.16.0.10";
        subnet = cluster.vpc.subnets.core-1;

        modules = [
          (bitte + /profiles/core.nix)
          (bitte + /profiles/bootstrapper.nix)
          ./secrets.nix
        ];

        securityGroupRules = {
          inherit (securityGroupRules)
            internet internal ssh http https haproxyStats vault-http grpc;
        };
      };

      core-2 = {
        instanceType = "t3a.medium";
        privateIP = "172.16.1.10";
        subnet = cluster.vpc.subnets.core-2;

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-3 = {
        instanceType = "t3a.medium";
        privateIP = "172.16.2.10";
        subnet = cluster.vpc.subnets.core-3;

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      monitoring = {
        instanceType = "t3a.large";
        privateIP = "172.16.0.20";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 40;
        route53.domains = [
          "*.${cluster.domain}"
        ];

        modules = let
          extraConfig = pkgs.writeText "extra-config.nix" ''
            { ... }: {
              services.vault-agent-core.vaultAddress =
                "https://${cluster.instances.core-1.privateIP}:8200";
            }
          '';
        in [
          (bitte + /profiles/monitoring.nix)
          ./secrets.nix
          ./ingress.nix
          "${extraConfig}"
        ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh http mantis-server;
        };
      };
    };
  };
}
