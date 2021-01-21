{ self, bitte, deployerPkgs, modulesPath, lib, pkgs, config, ... }:
let
  inherit (pkgs.terralib) sops2kms sops2region var;
  inherit (bitte.lib.net) cidr;
  inherit (deployerPkgs.terralib) earlyVar;
  inherit (builtins) readFile replaceStrings;
  inherit (lib) mapAttrs' nameValuePair flip attrValues listToAttrs forEach;
  inherit (config) cluster;
  inherit (import ./security-group-rules.nix { inherit config pkgs lib; })
    securityGroupRules;

in {
  imports = [ ./iam.nix ];

  services.consul.policies.developer.servicePrefix."mantispw-" = {
    policy = "write";
    intentions = "write";
  };

  services.nomad.policies = {
    admin.namespace."mantispw-*".policy = "write";
    developer = {
      namespace."mantispw-*".policy = "write";
      agent.policy = "read";
      quota.policy = "read";
      node.policy = "read";
      hostVolume."*".policy = "read";
    };
  };

  services.nomad.namespaces = {
    mantis-testnet.description = "Mantis testnet";
    mantis-iele.description = "Mantis IELE";
    mantis-qa-load.description = "Mantis QA Load";
    mantis-qa-fastsync.description = "Mantis QA FastSync";
    mantis-staging.description = "Mantis Staging";
  };

  cluster = {
    name = "mantispw-testnet";

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
    domain = "mantis.pw";
    kms = "arn:aws:kms:ca-central-1:166923377823:key/fe32bf5c-fc53-4602-a95b-1d8ee69013c7";
    # kms =
    #   "arn:aws:kms:eu-central-1:166923377823:key/745684e5-272e-49af-aad8-8b073b8d996a";
    s3Bucket = "iohk-mantispw-bitte";
    terraformOrganization = "mantispw";

    s3CachePubKey = lib.fileContents ../../../encrypted/nix-public-key-file;
    flakePath = ../../..;

    autoscalingGroups = listToAttrs (forEach [
      {
        region = "ca-central-1";
        desiredCapacity = 1;
      }
      {
        region = "us-east-1";
        desiredCapacity = 1;
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
        # privateIP = "172.16.0.10";
        # privateIP = earlyVar "cidrhost(${cluster.vpc.subnets.core-1.cidr}, 10)";
        privateIP = cidr.host 10 cluster.vpc.subnets.core-1.cidr;
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
        # privateIP = "172.16.1.10";
        # privateIP = earlyVar "cidrhost(${cluster.vpc.subnets.core-2.cidr}, 10)";
        privateIP = cidr.host 10 cluster.vpc.subnets.core-2.cidr;
        subnet = cluster.vpc.subnets.core-2;
        volumeSize = 100;

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-3 = {
        instanceType = "r5a.xlarge";
        # privateIP = "172.16.2.10";
        # privateIP = earlyVar "cidrhost(${cluster.vpc.subnets.core-3.cidr}, 10)";
        privateIP = cidr.host 10 cluster.vpc.subnets.core-3.cidr;
        subnet = cluster.vpc.subnets.core-3;
        volumeSize = 100;

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      monitoring = {
        instanceType = "t3a.large";
        # privateIP = "172.16.0.20";
        # privateIP = earlyVar "cidrhost(${cluster.vpc.subnets.core-1.cidr}, 20)";
        privateIP = cidr.host 20 cluster.vpc.subnets.core-1.cidr;
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 1000;
        route53.domains = [ "*.${cluster.domain}" ];

        modules = [
          (bitte + /profiles/monitoring.nix)
          ./monitoring-server.nix
          ./secrets.nix
          ./ingress.nix
          # ./docker-registry.nix
          ./minio.nix
        ];

        securityGroupRules = {
          inherit (securityGroupRules)
            internet internal ssh http mantis-server-public;
        };
      };
    };
  };
}
