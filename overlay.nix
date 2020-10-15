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
    rev = "515524986f20238085c1fddc811735697b974d89";
    ref = "chore/add-client-id-for-metrics";
    submodules = true;
  };

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

    [ $# -eq 1 ] || { echo "One argument is required. Pass the number of keys to generate."; exit 1; }

    desired="$1"

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
      secretKeyPath="kv/nomad-cluster/testnet/testnet-mantis-$count/secret-key"
      hashKeyPath="kv/nomad-cluster/testnet/testnet-mantis-$count/enode-hash"
      coinbasePath="kv/nomad-cluster/testnet/testnet-mantis-$count/coinbase"

      hashKey="$(vault kv get -field value "$hashKeyPath" || true)"

      if [ -z "$hashKey" ]; then
        if [ -s "$keyFile" ]; then
          echo "Uploading existing key from $keyFile to Vault"

          hashKey="$(tail -1 "$keyFile")"
          vault kv put "$hashKeyPath" "value=$hashKey"

          secretKey="$(head -1 "$keyFile")"
          vault kv put "$secretKeyPath" "value=$secretKey"

          coinbase="$(generateCoinbase "$secretKey")"
          vault kv put "$coinbasePath" "value=$coinbase"
        else
          echo "Generating key in $keyFile and uploading to Vault"

          len=0
          until [ $len -eq 194 ]; do
            echo "generating key..."
            len="$( eckeygen -Dconfig.file=${final.mantis}/conf/mantis.conf | tee "$keyFile" | wc -c )"
          done

          hashKey="$(tail -1 "$keyFile")"
          vault kv put "$hashKeyPath" "value=$hashKey"

          secretKey="$(head -1 "$keyFile")"
          vault kv put "$secretKeyPath" "value=$secretKey"

          coinbase="$(generateCoinbase "$secretKey")"
          vault kv put "$coinbasePath" "value=$coinbase"
        fi
      else
        echo "Downloading key for $keyFile from Vault"
        secretKey="$(vault kv get -field value "$secretKeyPath")"
        echo "$secretKey" > "$keyFile"
        echo "$hashKey" >> "$keyFile"

        coinbase="$(vault kv get -field value "$coinbasePath")"
        echo "$coinbase" > "$coinbaseFile"
      fi
    done
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
      final.bitte-tokens
      final.jq
    ];
  };

  # Used for caching
  devShellPath = prev.symlinkJoin {
    paths = final.devShell.buildInputs ++ [ final.mantis final.nixFlakes ];
    name = "devShell";
  };

  # inject vault-bin into bitte wrapper
  bitte = let
    bitte-nixpkgs = import self.inputs.nixpkgs {
      inherit system;
      overlays = [
        (final: prev: {
          vault-bin = self.inputs.bitte.legacyPackages.${system}.vault-bin;
        })
        self.inputs.bitte-cli.overlay.${system}
      ];
    };
  in bitte-nixpkgs.bitte;

  mantis-explorer =
    final.callPackage ./pkgs/mantis-explorer.nix { src = self.inputs.mantis-explorer; };

  nixosConfigurations =
    self.inputs.bitte.legacyPackages.${system}.mkNixosConfigurations
    final.clusters;

  clusters = self.inputs.bitte.legacyPackages.${system}.mkClusters {
    root = ./clusters;
    inherit self system;
  };

  inherit (self.inputs.bitte.legacyPackages.${system})
    vault-bin mkNomadJob terraform-with-plugins systemdSandbox nixFlakes nomad
    consul consul-template bitte-tokens;

  nomadJobs = let
    jobsDir = ./jobs;
    contents = builtins.readDir jobsDir;
    toImport = name: type: type == "regular" && lib.hasSuffix ".nix" name;
    fileNames = builtins.attrNames (lib.filterAttrs toImport contents);
    imported = lib.forEach fileNames
      (fileName: final.callPackage (jobsDir + "/${fileName}") { });
  in lib.foldl' lib.recursiveUpdate { } imported;
}
