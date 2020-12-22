{ mkNomadJob
, pkgs
, lib
, domain
, mantis
, mantis-source
, mantis-faucet
, mantis-faucet-source
, morpho-node
, morpho-source
, dockerImages
, mantis-explorer

# NOTE: Copy this file and change the next line if you want to start your own cluster!
, namespace ? "mantis-kevm"
, datacenters ? [ "us-east-2" "eu-west-1" "eu-central-1" ]
, amountOfMorphoNodes ? 5
}:

let
  mantisPackages = lib.makeScope pkgs.newScope (self: with self; {
    inherit namespace lib domain;

    vault = {
      policies = [ "nomad-cluster" ];
      changeMode = "noop";
    };

    genesisJson = {
      data = ''
        {{- with secret "kv/nomad-cluster/${namespace}/genesis" -}}
        {{.Data.data | toJSON }}
        {{- end -}}
      '';
      changeMode = "restart";
      destination = "local/genesis.json";
    };


    morphoNodes = lib.forEach (lib.range 1 amountOfMorphoNodes) (n: {
      name = "obft-node-${toString n}";
      nodeNumber = n;
    });

    # all files within the jobs directory get called with callPackage, so
    # these files can't exist in the jobs directory
    # callPackage can only be used with derivations, use import+inherit for configs
    config = import ../instances/config.nix {
      inherit namespace lib amountOfMorphoNodes;
    };

    mkMorpho = import ../instances/mk-morpho.nix {
      inherit lib morpho-source dockerImages vault namespace;
    };

    mkMantis = import ../instances/mk-mantis.nix {
      inherit dockerImages mantis-source vault;
    };

    mkMiner = import ../instances/mk-miner.nix { inherit lib mkMantis; };

    mkPassive = import ../instances/mk-passive.nix {
      inherit namespace lib mkMantis mantis-source miners config genesisJson;
    };

    explorer = import ../instances/explorer.nix {
      inherit namespace domain dockerImages;
    };

    faucet = import ../instances/faucet.nix {
      inherit namespace lib config domain dockerImages mantis-faucet-source vault genesisJson;
    };

    updateOneAtATime = {
      maxParallel = 1;
      # healthCheck = "checks"
      minHealthyTime = "30s";
      healthyDeadline = "10m";
      progressDeadline = "20m";
      autoRevert = false;
      autoPromote = false;
      canary = 0;
      stagger = "1m";
    };

    amountOfMiners = 5;

    miners = lib.forEach (lib.range 1 amountOfMiners) (num: {
      name = "mantis-${toString num}";
      requiredPeerCount = num - 1;
      publicServerPort = 9000 + num; # routed through haproxy/ingress
      publicDiscoveryPort = 9500 + num; # routed through haproxy/ingress
      publicRpcPort = 10000 + num; # routed through haproxy/ingress
    });

    minerJobs = lib.listToAttrs (lib.forEach miners (miner: {
      name = "${namespace}-${miner.name}";
      value = mkNomadJob miner.name {
        type = "service";
        inherit datacenters namespace;

        update = updateOneAtATime;

        taskGroups = lib.listToAttrs [ (mkMiner miner) ];
      };
    }));
  });
in with mantisPackages; minerJobs // {
  inherit mantisPackages;
  "${namespace}-mantis-passive" = mkNomadJob "mantis-passive" {
    type = "service";
    inherit datacenters namespace;

    update = updateOneAtATime;

    taskGroups = { passive = mkPassive 3; };
  };

  "${namespace}-morpho" = mkNomadJob "morpho" {
    type = "service";
    inherit datacenters namespace;

    update = updateOneAtATime;

    taskGroups = let
      generateMorphoTaskGroup = nbNodes: node:
        lib.nameValuePair node.name (lib.recursiveUpdate (mkPassive 1)
          (mkMorpho (node // { inherit nbNodes; })));
      morphoTaskGroups =
        map (generateMorphoTaskGroup (builtins.length morphoNodes)) morphoNodes;
    in lib.listToAttrs morphoTaskGroups;
  };

  "${namespace}-explorer" = mkNomadJob "explorer" {
    type = "service";
    inherit datacenters namespace;

    taskGroups.explorer = explorer;
  };

  "${namespace}-faucet" = mkNomadJob "faucet" {
    type = "service";
    inherit datacenters namespace;

    taskGroups.faucet = faucet;
  };

  "${namespace}-backup" = mkNomadJob "backup" {
    type = "batch";
    inherit datacenters namespace;

    periodic = {
      cron = "15 */1 * * * *";
      prohibitOverlap = true;
      timeZone = "UTC";
    };

    taskGroups.backup = let name = "${namespace}-backup";
    in import ./tasks/backup.nix {
      inherit lib dockerImages namespace name mantis;
      config = config {
        inherit namespace name;
        miningEnabled = false;
      };
    };
  };
}

