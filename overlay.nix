inputs: final: prev:
let
  lib = final.lib;
  # Little convenience function helping us to containing the bash
  # madness: forcing our bash scripts to be shellChecked.
  writeBashChecked = final.writers.makeScriptWriter {
    interpreter = "${final.bash}/bin/bash";
    check = final.writers.writeBash "shellcheck-check" ''
      ${final.shellcheck}/bin/shellcheck -x "$1"
    '';
  };
  writeBashBinChecked = name: writeBashChecked "/bin/${name}";
in {
  inherit writeBashChecked writeBashBinChecked;
  # we cannot specify mantis as a flake input due to:
  # * the branch having a slash
  # * the submodules syntax is broken
  # And here we cannot specify simply a branch since that's not reproducible,
  # so we use the commit instead.
  # The branch was `chore/update-sbt-add-nix`, for future reference.

  mantis-staging-source = builtins.fetchGit {
    url = "https://github.com/input-output-hk/mantis";
    rev = "427d8e8ef30f1038b33719f1e0fa50a8352c33c4";
    ref = "develop";
    submodules = true;
  };

  mantis-faucet-source = builtins.fetchGit {
    url = "https://github.com/input-output-hk/mantis";
    rev = "07e617cdd1bfc76ad1a8472305f0e5e60e2801e1";
    ref = "develop";
    submodules = true;
  };

  mantis = inputs.mantis.defaultPackage.${final.system};

  mantis-staging = import final.mantis-staging-source {
    src = final.mantis-staging-source;
    inherit (final) system;
  };

  mantis-faucet-web =
    inputs.mantis-faucet-web.defaultPackage.${final.system}.overrideAttrs
    (old: {
      FAUCET_NODE_URL = "https://mantis-testnet-faucet.mantis.ws";
      MANTIS_VM = "Mantis Testnet";
    });

  mantis-faucet-nginx = final.callPackage ./pkgs/nginx.nix {
    package = final.mantis-faucet-web;
    target = "/mantis-faucet";
  };

  mantis-faucet-server = final.callPackage ./pkgs/mantis-faucet-server.nix { };

  mantis-explorer = inputs.mantis-explorer.defaultPackage.${final.system}.overrideAttrs (_: {
    MANTIS_VM = "Mamba Atago";
  });

  mantis-explorer-nginx = prev.callPackage ./pkgs/nginx.nix {
    package = final.mantis-explorer;
    target = "/mamba-explorer";
  };

  morpho-source = inputs.morpho-node;

  morpho-node = inputs.morpho-node.defaultPackage.${final.system};

  morpho-node-entrypoint = final.callPackage ./pkgs/morpho-node.nix { };

  # Any:
  # - run of this command with a parameter different than the testnet (currently 10)
  # - change in the genesis file here
  # Requires an update on the mantis repository and viceversa
  generate-mantis-keys = final.writeBashBinChecked "generate-mantis-keys" ''
    export PATH="${
      lib.makeBinPath (with final; [
        coreutils
        curl
        gawk
        gnused
        gnused
        jq
        mantis
        netcat
        vault-bin
        which
        shellcheck
        tree
      ])
    }"

    . ${./pkgs/generate-mantis-keys.sh}
  '';

  generate-mantis-qa-genesis =
    final.writeShellScriptBin "generate-mantis-qa-genesis" ''
      set -xeuo pipefail

      prefix="$1"

      read genesis <<EOF
        ${
          builtins.toJSON {
            extraData = "0x00";
            nonce = "0x0000000000000042";
            gasLimit = "0xffffffffff";
            difficulty = "0x400";
            ommersHash =
              "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347";
            timestamp = "0x00";
            coinbase = "0x0000000000000000000000000000000000000000";
            mixHash =
              "0x0000000000000000000000000000000000000000000000000000000000000000";
            alloc = {
              "5a3b6d6e72db079655c6327c722cd40a60c888b4" = {
                _comments =
                  "PrivateKey in use: 00804c5be5b608c6a03ae5db56ac29c97192ac8b87720e7009dbc735460c7d8122; Coinbase";
                balance = "0";
              };
              "7fbcf9190993aa5232def0238e129ce7b7e42da7" = {
                _comments =
                  "PrivateKey in use: 00feedec7150e9562b037727cfb33a51c753357dec7f36d659b0a531a4a5aa4000";
                balance =
                  "1606938044258990275541962092341162602522202993782792835301376";
              };
              "316158e265fa708c623cc3094b2bb5889e0f5ca5" = {
                balance = "100000000000000000000";
              };
              "b9ec69316a8810db91c36de79c4f1e785f2c35fc" = {
                balance = "100000000000000000000";
              };
              "488c10c91771d3b3c25f63b6414309b119baacb5" = {
                balance = "100000000000000000000";
              };
            };
          }
        }
      EOF

      echo "$genesis" | vault kv put kv/nomad-cluster/$prefix/qa-genesis -
    '';

  checkFmt = final.writeShellScriptBin "check_fmt.sh" ''
    export PATH="$PATH:${lib.makeBinPath (with final; [ git nixfmt gnugrep ])}"
    . ${./pkgs/check_fmt.sh}
  '';

  dockerImagesCue = let
    images = lib.mapAttrs (n: v: {
      name = builtins.unsafeDiscardStringContext v.image.imageName;
      tag = builtins.unsafeDiscardStringContext v.image.imageTag;
      url = builtins.unsafeDiscardStringContext v.id;
    }) final.dockerImages;
    imagesJson = final.writeText "images.json"
      (builtins.toJSON { dockerImages = images; });
  in final.runCommand "docker_images.cue" { buildInputs = [ final.cue ]; } ''
    cue import -p bitte json: - < ${imagesJson} > $out
  '';

  devShell = let
    cluster = "mantis-testnet";
    domain = final.clusters.${cluster}.proto.config.cluster.domain;
  in prev.mkShell {
    # for bitte-cli
    LOG_LEVEL = "debug";

    BITTE_CLUSTER = cluster;
    AWS_PROFILE = "mantis";
    AWS_DEFAULT_REGION = final.clusters.${cluster}.proto.config.cluster.region;
    NOMAD_NAMESPACE = "mantis-testnet";

    VAULT_ADDR = "https://vault.${domain}";
    NOMAD_ADDR = "https://nomad.${domain}";
    CONSUL_HTTP_ADDR = "https://consul.${domain}";

    buildInputs = with final; [
      bitte
      scaler-guard
      terraform-with-plugins
      sops
      vault-bin
      openssl
      cfssl
      nixfmt
      awscli
      nomad
      consul
      consul-template
      direnv
      jq
      fd
      cue
      # final.crystal
      # final.pkgconfig
      # final.openssl
    ];
  };

  # Used for caching
  devShellPath = prev.symlinkJoin {
    paths = final.devShell.buildInputs;
    name = "devShell";
  };

  debugUtils = with final; [
    bashInteractive
    coreutils
    curl
    dnsutils
    fd
    gawk
    gnugrep
    iproute
    jq
    lsof
    netcat
    nettools
    procps
    tree
  ];

  inherit ((inputs.nixpkgs.legacyPackages.${final.system}).dockerTools)
    buildImage buildLayeredImage shadowSetup;

  restic-backup = final.callPackage ./pkgs/backup { };
}
