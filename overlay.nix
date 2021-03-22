inputs: final: prev:
let
  lib = final.lib;
  system = final.system;
  # Little convenience function helping us to containing the bash
  # madness: forcing our bash scripts to be shellChecked.
  writeBashChecked = final.writers.makeScriptWriter {
    interpreter = "${final.bash}/bin/bash";
    check = final.writers.writeBash "shellcheck-check" ''
      ${final.shellcheck}/bin/shellcheck -x "$1"
    '';
  };
  writeBashBinChecked = name: writeBashChecked "/bin/${name}";

  cluster = "mantis-kevm";
  domain = final.clusters.${cluster}.proto.config.cluster.domain;
in {
  inherit domain writeBashChecked writeBashBinChecked;
  # we cannot specify mantis as a flake input due to:
  # * the branch having a slash
  # * the submodules syntax is broken
  # And here we cannot specify simply a branch since that's not reproducible,
  # so we use the commit instead.
  # The branch was `chore/update-sbt-add-nix`, for future reference.
  mantis-source = builtins.fetchGit {
    url = "https://github.com/input-output-hk/mantis";
    rev = "4fc1d4ab5396f206319387e0283d597ea390f6b8";
    ref = "develop";
    submodules = true;
  };

  kevm = final.callPackage ./pkgs/kevm.nix { };

  mantis-iele-source = builtins.fetchGit {
    url = "https://github.com/input-output-hk/mantis";
    rev = "e8af13b5a237560b0186b231dfeefb7990bdfd1a";
    ref = "iele_testnet_2020";
    submodules = true;
  };

  mantis-iele = import final.mantis-iele-source { inherit system; };

  inherit (final.dockerTools) buildLayeredImage;

  mkEnv = lib.mapAttrsToList (key: value: "${key}=${value}");

  mantis-faucet-source = builtins.fetchGit {
    url = "https://github.com/input-output-hk/mantis";
    rev = "07e617cdd1bfc76ad1a8472305f0e5e60e2801e1";
    ref = "develop";
    submodules = true;
  };

  restic-backup = final.callPackage ./pkgs/backup { };

  mantis = import final.mantis-source { inherit system; };

  mantis-faucet = import final.mantis-faucet-source { inherit system; };

  morpho-source = inputs.morpho-node;

  morpho-node = inputs.morpho-node.morpho-node.${system};

  mantis-kevm-src = builtins.fetchGit {
    url = "https://github.com/input-output-hk/mantis";
    ref = "develop";
    rev = "e8af13b5a237560b0186b231dfeefb7990bdfd1a";
    submodules = true;
  };

  mantis-kevm = import final.mantis-kevm-src { system = final.system; };

  iele = final.callPackage ./pkgs/iele.nix { };

  generate-mantis-keys = final.writeBashBinChecked "generate-mantis-keys" ''
    export PATH="${
      lib.makeBinPath (with final; [
        coreutils
        curl
        gawk
        gnused
        jq
        mantis
        netcat
        shellcheck
        tree
        vault-bin
        which
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

  debugUtils = with final; [
    bashInteractive
    bat
    coreutils
    curl
    dnsutils
    fd
    gawk
    gnugrep
    gnused
    htop
    iproute
    jq
    less
    lsof
    netcat
    nettools
    procps
    ripgrep
    shellcheck
    strace
    tmux
    tree
    utillinux
    vim
    which
  ];

  devShell = prev.mkShell {
    # for bitte-cli
    LOG_LEVEL = "debug";

    BITTE_CLUSTER = cluster;
    AWS_PROFILE = "mantis-kevm";
    AWS_DEFAULT_REGION = final.clusters.${cluster}.proto.config.cluster.region;

    VAULT_ADDR = "https://vault.${domain}";
    NOMAD_ADDR = "https://nomad.${domain}";
    CONSUL_HTTP_ADDR = "https://consul.${domain}";

    buildInputs = with final; [
      awscli
      bitte
      cfssl
      consul
      consul-template
      cue
      direnv
      fd
      jq
      nixfmt
      nomad
      openssl
      pkgconfig
      restic
      sops
      terraform-with-plugins
      vault-bin
    ];
  };

  # Used for caching
  devShellPath = prev.symlinkJoin {
    paths = final.devShell.buildInputs
      ++ [ final.grafana-loki final.mantis final.mantis-faucet ];
    name = "devShell";
  };

  mantis-explorer = inputs.mantis-explorer.defaultPackage.${system};
  mantis-faucet-web = inputs.mantis-faucet-web.defaultPackage.${system};
}
