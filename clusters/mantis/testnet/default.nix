{ self, lib, pkgs, config, ... }:
let
  inherit (pkgs.terralib) sops2kms sops2region cidrsOf;
  inherit (builtins) readFile replaceStrings;
  inherit (lib) mapAttrs' nameValuePair flip attrValues listToAttrs forEach;
  inherit (config) cluster;
  inherit (import ./security-group-rules.nix { inherit config pkgs lib; })
    securityGroupRules;

  bitte = self.inputs.bitte;

in {
  imports = [ ./iam.nix ./nix.nix ];

  services.nomad.namespaces = {
    mantis-testnet.description = "Mantis testnet";
    mantis-iele.description = "Mantis IELE";
    mantis-qa-load.description = "Mantis QA Load";
    mantis-qa-fastsync.description = "Mantis QA FastSync";
    mantis-staging.description = "Mantis Staging";
    mantis-unstable.description = "Mantis Unstable";
    mantis-paliga.description = "Mantis Paliga";
  };

  services.consul.policies.developer.servicePrefix."mantis-" = {
    policy = "write";
    intentions = "write";
  };

  services.nomad.policies = {
    admin.namespace."mantis-*".policy = "write";
    developer = {
      namespace."mantis-*".policy = "write";
      agent.policy = "read";
      quota.policy = "read";
      node.policy = "read";
      hostVolume."*".policy = "read";
    };
  };

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
        desiredCapacity = 10;
      }
      {
        region = "us-east-2";
        desiredCapacity = 10;
      }
    ] (args:
      let
        attrs = ({
          desiredCapacity = 1;
          maxSize = 40;
          instanceType = "c5.2xlarge";
          associatePublicIP = true;
          maxInstanceLifetime = 0;
          iam.role = cluster.iam.roles.client;
          iam.instanceProfile.role = cluster.iam.roles.client;

          modules = [
            (bitte + /profiles/client.nix)
            self.inputs.ops-lib.nixosModules.zfs-runtime
            "${self.inputs.nixpkgs}/nixos/modules/profiles/headless.nix"
            "${self.inputs.nixpkgs}/nixos/modules/virtualisation/ec2-data.nix"
            ./secrets.nix
            ./docker-auth.nix
            ./nix.nix
            ./reserve.nix
          ];

          securityGroupRules = {
            inherit (securityGroupRules)
              internet internal ssh mantis-rpc mantis-server;
          };
        } // args);
        asgName = "client-${attrs.region}-${
            replaceStrings [ "." ] [ "-" ] attrs.instanceType
          }";
      in nameValuePair asgName attrs));

    instances = {
      core-1 = {
        instanceType = "r5a.xlarge";
        privateIP = "172.16.0.10";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 100;

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
        instanceType = "r5a.xlarge";
        privateIP = "172.16.1.10";
        subnet = cluster.vpc.subnets.core-2;
        volumeSize = 100;

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-3 = {
        instanceType = "r5a.xlarge";
        privateIP = "172.16.2.10";
        subnet = cluster.vpc.subnets.core-3;
        volumeSize = 100;

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      monitoring = {
        instanceType = "t3a.large";
        privateIP = "172.16.0.20";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 1000;
        route53.domains = [
          "consul.${cluster.domain}"
          "nomad.${cluster.domain}"
          "vault.${cluster.domain}"
          "monitoring.${cluster.domain}"
        ];

        modules = [
          (bitte + /profiles/monitoring.nix)
          ./monitoring-server.nix
          ./secrets.nix
        ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh http;
        };
      };

      routing = {
        instanceType = "t3a.large";
        privateIP = "172.16.1.20";
        subnet = cluster.vpc.subnets.core-2;
        volumeSize = 100;
        route53.domains = [ "*.${cluster.domain}" ];

        modules = [ ./traefik.nix ];

        securityGroupRules = {
          inherit (securityGroupRules)
            internet internal ssh http routing mantis-server-public
            mantis-discovery-public;
        };
      };
    };
  };
}
