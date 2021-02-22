inputs: final: prev:
let
  lib = final.lib;
  # Little convenience function helping us to containing the bash
  # madness: forcing our bash scripts to be shellChecked.
  writeBashChecked = final.writers.makeScriptWriter {
    interpreter = "${final.bash}/bin/bash";
    check = final.writers.writeBash "shellcheck-check" ''
      ${final.shellcheck}/bin/shellcheck "$1"
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

  mantis-source = builtins.fetchGit {
    url = "https://github.com/input-output-hk/mantis";
    rev = "4fc1d4ab5396f206319387e0283d597ea390f6b8";
    ref = "develop";
    submodules = true;
  };

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

  restic-backup = final.callPackage ./pkgs/backup { };

  mantis = import final.mantis-source { inherit (final) system; };

  mantis-explorer = inputs.mantis-explorer.defaultPackage.${final.system};

  mantis-faucet-web = inputs.mantis-faucet-web.defaultPackage.${final.system};

  mantis-staging = import final.mantis-staging-source {
    src = final.mantis-staging-source;
    inherit (final) system;
  };

  mantis-faucet = import final.mantis-faucet-source { inherit (final) system; };

  mantis-explorer-server = prev.callPackage ./pkgs/mantis-explorer-server.nix {
    inherit (inputs.inclusive.lib) inclusive;
  };
  morpho-source = inputs.morpho-node;

  morpho-node = inputs.morpho-node.defaultPackage.${final.system};

  # Any:
  # - run of this command with a parameter different than the testnet (currently 10)
  # - change in the genesis file here
  # Requires an update on the mantis repository and viceversa
  generate-mantis-keys = let
    mantisConfigJson = {
      mantis = {
        consensus.mining-enabled = false;
        blockchains.network = "testnet-internal-nomad";

        network.rpc = {
          http = {
            mode = "http";
            interface = "0.0.0.0";
            port = 8546;
            cors-allowed-origins = "*";
          };
        };
      };
    };

    mantisConfigHocon =
      prev.runCommand "mantis.conf" { buildInputs = [ prev.jq ]; } ''
        cat <<EOF > $out
        include "${final.mantis}/conf/testnet-internal-nomad.conf"
        EOF

        jq . < ${
          prev.writeText "mantis.json" (builtins.toJSON mantisConfigJson)
        } \
        | head -c -2 \
        | tail -c +2 \
        | sed 's/^  //' \
        >> $out
      '';
  in writeBashBinChecked "generate-mantis-keys" ''
    set -xeuo pipefail

    export PATH="${
      lib.makeBinPath (with final; [
        final.coreutils
        final.mantis
        final.gawk
        final.vault-bin
        final.gnused
        final.curl
        final.jq
        final.netcat
        final.gnused
      ])
    }"

    [ $# -eq 3 ] || { echo "Three arguments are required. Pass the prefix, the number of mantis keys to generate and the number of OBFT keys to generate."; exit 1; }

    prefix="$1"
    desired="$2"
    desiredObft="$3"
    mkdir -p secrets/"$prefix"

    echo "generating $desired keys"

    tmpdir="$(mktemp -d)"

    mantis "-Duser.home=$tmpdir" "-Dconfig.file=${mantisConfigHocon}" > /dev/null &
    pid="$!"
    on_exit() {
      kill "$pid"
      while kill -0 "$pid"; do
        sleep 0.1
      done
      rm -rf "$tmpdir"
    }
    trap on_exit EXIT

    while ! nc -z 127.0.0.1 8546; do
      sleep 0.1 # wait for 1/10 of the second before check again
    done

    generateCoinbase() {
      curl -s http://127.0.0.1:8546 -H 'Content-Type: application/json' -d @<(cat <<EOF
        {
          "jsonrpc": "2.0",
          "method": "personal_importRawKey",
          "params": ["$1", ""],
          "id": 1
        }
    EOF
      ) | jq -e -r .result | sed 's/^0x//'
    }

    nodes="$(seq -f "mantis-%g" "$desired"; seq -f "obft-node-%g" "$desiredObft")"
    for node in $nodes; do
      mantisKeyFile="secrets/$prefix/mantis-$node.key"
      coinbaseFile="secrets/$prefix/$node.coinbase"
      coinbasePath="kv/nomad-cluster/$prefix/$node/coinbase"
      mantisSecretKeyPath="kv/nomad-cluster/$prefix/$node/secret-key"
      hashKeyPath="kv/nomad-cluster/$prefix/$node/enode-hash"
      accountPath="kv/nomad-cluster/$prefix/$node/account"
      genesisPath="kv/nomad-cluster/$prefix/genesis"

      obftKeyFile="secrets/$prefix/obft-$node.key"
      obftSecretKeyPath="kv/nomad-cluster/$prefix/$node/obft-secret-key"
      obftPublicKeyPath="kv/nomad-cluster/$prefix/$node/obft-public-key"

      hashKey="$(vault kv get -field value "$hashKeyPath" || true)"

      if [ -z "$hashKey" ]; then
        if ! [ -s "$mantisKeyFile" ]; then
          echo "Generating key in $mantisKeyFile"
          until [ -s "$mantisKeyFile" ]; do
            echo "generating key..."
            eckeygen 1 | sed -r '/^\s*$/d' > "$mantisKeyFile"
          done
        fi

        echo "Uploading existing key from $mantisKeyFile to Vault"

        hashKey="$(tail -1 "$mantisKeyFile")"
        vault kv put "$hashKeyPath" "value=$hashKey"

        secretKey="$(head -1 "$mantisKeyFile")"
        vault kv put "$mantisSecretKeyPath" "value=$secretKey"

        coinbase="$(generateCoinbase "$secretKey")"
        vault kv put "$coinbasePath" "value=$coinbase"

        vault kv put "$accountPath" - < "$tmpdir"/.mantis/testnet-internal-nomad/keystore/*"$coinbase"
      else
        echo "Downloading key for $mantisKeyFile from Vault"
        secretKey="$(vault kv get -field value "$mantisSecretKeyPath")"
        echo "$secretKey" > "$mantisKeyFile"
        echo "$hashKey" >> "$mantisKeyFile"

        coinbase="$(vault kv get -field value "$coinbasePath")"
        echo "$coinbase" > "$coinbaseFile"
      fi

      # OBFT-related keys for obft nodes
      # Note: a OBFT node needs *both* the mantis and OBFT keys to
      # work.
      if [[ "$node" =~ ^obft-node-[0-9]+$ ]]; then
        obftPublicKey="$(vault kv get -field value "$obftPublicKeyPath" || true)"
        if [ -z "$obftPublicKey" ]; then
          if ! [ -s "$obftKeyFile" ]; then
            echo "generating OBFT key..."
            until [ -s "$obftKeyFile" ]; do
                echo "generating key..."
                eckeygen 1 | sed -r '/^\s*$/d' > "$obftKeyFile"
            done
          fi

          echo "Uploading OBFT keys"
          obftPubKey="$(tail -1 "$obftKeyFile")"
          vault kv put "$obftPublicKeyPath" "value=$obftPubKey"
          obftSecretKey="$(head -1 "$obftKeyFile")"
          vault kv put "$obftSecretKeyPath" "value=$obftSecretKey"
        else
          echo "Downloading OBFT keys"
          obftSecretKey="$(vault kv get -field value "obftSecretKeyPath")"
          echo "$obftSecretKey" > "$obftKeyFile"
          echo "$obftPublicKey" >> "$obftKeyFile"
        fi
      fi

    done

    read -r genesis <<EOF
      ${
        builtins.toJSON {
          extraData = "0x00";
          nonce = "0x0000000000000042";
          gasLimit = "0x7A1200";
          difficulty = "0xF4240";
          ommersHash =
            "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347";
          timestamp = "0x5FA34080";
          coinbase = "0x0000000000000000000000000000000000000000";
          mixHash =
            "0x0000000000000000000000000000000000000000000000000000000000000000";
          alloc = { };
        }
      }
    EOF

    for count in $(seq "$desired"); do
      updatedGenesis="$(
        echo "$genesis" \
        | jq --arg address "$(< "secrets/$prefix/mantis-$count.coinbase")" \
          '.alloc[$address] = {"balance": "1606938044258990275541962092341162602522202993782792835301376"}'
      )"
      genesis="$updatedGenesis"
    done

    echo "$genesis" | vault kv put "$genesisPath" -
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
      nixFlakes
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
    paths = final.devShell.buildInputs ++ [
      final.grafana-loki
      final.mantis
      final.mantis-faucet
      final.nixFlakes
    ];
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

  mkEnv = lib.mapAttrsToList (key: value: "${key}=${value}");
}
