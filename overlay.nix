{ system, self }:
final: prev:
let lib = final.lib;
in {
  # we cannot specify mantis as a flake input due to:
  # * the branch having a slash
  # * the submodules syntax is broken
  # And here we cannot specify simply a branch since that's not reproducible,
  # so we use the commit instead.
  # The branch was `chore/update-sbt-add-nix`, for future reference.
  mantis-source = builtins.fetchGit {
    url = "https://github.com/input-output-hk/mantis";
    rev = "cd1f83c755a0a50301b5e822424b6346e32b0e7a";
    ref = "develop";
    submodules = true;
  };

  mantis-automation =
    import self.inputs.mantis-automation { inherit system; };

  mantis = import final.mantis-source { inherit system; };

  generate-mantis-keys = let
    mantisConfigJson = {
      mantis = {
        consensus.mining-enabled = false;
        blockchains.network = "testnet-internal";

        network.rpc = {
          http = {
            mode = "http";
            interface = "0.0.0.0";
            port = 8546;
            cors-allowed-origins = "*";
          };
          apis = "eth,web3,net,personal,daedalus,debug,qa";
        };
      };
    };

    mantisConfigHocon =
      prev.runCommand "mantis.conf" { buildInputs = [ prev.jq ]; } ''
        cat <<EOF > $out
        include "${final.mantis}/conf/testnet-internal.conf"
        EOF

        jq . < ${
          prev.writeText "mantis.json" (builtins.toJSON mantisConfigJson)
        } \
        | head -c -2 \
        | tail -c +2 \
        | sed 's/^  //' \
        >> $out
      '';
  in final.writeShellScriptBin "generate-mantis-keys" ''
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

    [ $# -eq 2 ] || { echo "Two arguments are required. Pass the prefix and the number of keys to generate."; exit 1; }

    prefix="$1"
    desired="$2"
    mkdir -p secrets

    echo "generating $desired keys"

    tmpdir="$(mktemp -d)"

    mantis "-Duser.home=$tmpdir" "-Dconfig.file=${mantisConfigHocon}" &
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

    for count in $(seq "$desired"); do
      keyFile="secrets/mantis-$count.key"
      coinbaseFile="secrets/mantis-$count.coinbase"
      secretKeyPath="kv/nomad-cluster/$prefix/testnet-mantis-$count/secret-key"
      hashKeyPath="kv/nomad-cluster/$prefix/testnet-mantis-$count/enode-hash"
      coinbasePath="kv/nomad-cluster/$prefix/testnet-mantis-$count/coinbase"
      accountPath="kv/nomad-cluster/$prefix/testnet-mantis-$count/account"
      genesisPath="kv/nomad-cluster/$prefix/genesis"

      hashKey="$(vault kv get -field value "$hashKeyPath" || true)"

      if [ -z "$hashKey" ]; then
        if ! [ -s "$keyFile" ]; then
          echo "Generating key in $keyFile"

          len=0
          until [ $len -eq 194 ]; do
            echo "generating key..."
            len="$( eckeygen -Dconfig.file=${final.mantis}/conf/mantis.conf | tee "$keyFile" | wc -c )"
          done
        fi

        echo "Uploading existing key from $keyFile to Vault"

        hashKey="$(tail -1 "$keyFile")"
        vault kv put "$hashKeyPath" "value=$hashKey"

        secretKey="$(head -1 "$keyFile")"
        vault kv put "$secretKeyPath" "value=$secretKey"

        coinbase="$(generateCoinbase "$secretKey")"
        vault kv put "$coinbasePath" "value=$coinbase"

        cat $tmpdir/.mantis/testnet-internal/keystore/*$coinbase | vault kv put "$accountPath" -
      else
        echo "Downloading key for $keyFile from Vault"
        secretKey="$(vault kv get -field value "$secretKeyPath")"
        echo "$secretKey" > "$keyFile"
        echo "$hashKey" >> "$keyFile"

        coinbase="$(vault kv get -field value "$coinbasePath")"
        echo "$coinbase" > "$coinbaseFile"
      fi
    done

    read genesis <<EOF
      ${
        builtins.toJSON {
          extraData = "0x00";
          nonce = "0x0000000000000042";
          gasLimit = "0x2fefd8";
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
        | jq --arg address "$(< "secrets/mantis-$count.coinbase")" \
          '.alloc[$address] = {"balance": "1606938044258990275541962092341162602522202993782792835301376"}'
      )"
      genesis="$updatedGenesis"
    done

    echo "$genesis" | vault kv put $genesisPath -
  '';

  generate-mantis-qa-genesis = final.writeShellScriptBin "generate-mantis-qa-genesis" ''
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
              _comments = "PrivateKey in use: 00804c5be5b608c6a03ae5db56ac29c97192ac8b87720e7009dbc735460c7d8122; Coinbase";
              balance = "0";
            };
            "7fbcf9190993aa5232def0238e129ce7b7e42da7" = {
              _comments = "PrivateKey in use: 00feedec7150e9562b037727cfb33a51c753357dec7f36d659b0a531a4a5aa4000";
              balance = "1606938044258990275541962092341162602522202993782792835301376";
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
    NIX_USER_CONF_FILES = ./nix.conf;

    buildInputs = [
      final.bitte
      final.terraform-with-plugins
      prev.sops
      final.vault-bin
      final.openssl
      final.cfssl
      final.nixfmt
      final.awscli
      final.nomad
      final.consul
      final.consul-template
      final.python38Packages.pyhcl
      final.direnv
      final.nixFlakes
      final.jq
    ];
  };

  # Used for caching
  devShellPath = prev.symlinkJoin {
    paths = final.devShell.buildInputs
      ++ [ final.mantis final.nixFlakes final.mantis-automation ];
    name = "devShell";
  };

  mantis-explorer = final.callPackage ./pkgs/mantis-explorer.nix {
    src = self.inputs.mantis-explorer;
  };

  nixosConfigurations =
    self.inputs.bitte.legacyPackages.${system}.mkNixosConfigurations
    final.clusters;

  clusters = self.inputs.bitte.legacyPackages.${system}.mkClusters {
    root = ./clusters;
    inherit self system;
  };

  inherit (self.inputs.bitte.legacyPackages.${system})
    bitte vault-bin mkNomadJob terraform-with-plugins systemdSandbox nixFlakes
    nomad consul consul-template;

  nomadJobs = let
    jobsDir = ./jobs;
    contents = builtins.readDir jobsDir;
    toImport = name: type: type == "regular" && lib.hasSuffix ".nix" name;
    fileNames = builtins.attrNames (lib.filterAttrs toImport contents);
    imported = lib.forEach fileNames
      (fileName: final.callPackage (jobsDir + "/${fileName}") { });
  in lib.foldl' lib.recursiveUpdate { } imported;

  dockerImages = let
    imageDir = ./docker;
    contents = builtins.readDir imageDir;
    toImport = name: type: type == "regular" && lib.hasSuffix ".nix" name;
    fileNames = builtins.attrNames (lib.filterAttrs toImport contents);
    imported = lib.forEach fileNames
      (fileName: final.callPackages (imageDir + "/${fileName}") { });
    merged = lib.foldl' lib.recursiveUpdate { } imported;
  in lib.flip lib.mapAttrs merged (key: image: {
    inherit image;

    id = "${image.imageName}:${image.imageTag}";

    push = final.writeShellScriptBin "push" ''
      set -euo pipefail
      echo "Pushing ${image} (${image.imageName}:${image.imageTag}) ..."
      docker load -i ${image}
      docker push ${image.imageName}:${image.imageTag}
    '';

    load = builtins.trace key (final.writeShellScriptBin "load" ''
      set -euo pipefail
      echo "Loading ${image} (${image.imageName}:${image.imageTag}) ..."
      docker load -i ${image}
    '');
  });

  push-docker-images = final.writeShellScriptBin "push-docker-images" ''
    set -euo pipefail
    ${lib.concatStringsSep "\n"
    (lib.mapAttrsToList (key: value: "${value.push}/bin/push")
      final.dockerImages)}
  '';

  load-docker-images = final.writeShellScriptBin "load-docker-images" ''
    set -euo pipefail
    ${lib.concatStringsSep "\n"
    (lib.mapAttrsToList (key: value: "${value.load}/bin/load")
      final.dockerImages)}
  '';

  inherit ((self.inputs.nixpkgs.legacyPackages.${system}).dockerTools)
    buildLayeredImage;

  mkEnv = lib.mapAttrsToList (key: value: "${key}=${value}");
}
