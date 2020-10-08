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
    rev = "8e45269f6961066ad638ae14b6e84692c220f28b";
    ref = "develop";
    submodules = true;
  };

  mantis = import final.mantis-source { inherit system; };

  generate-mantis-keys = final.writeShellScriptBin "generate-mantis-keys" ''
    set -euo pipefail

    export PATH="${
      lib.makeBinPath (with final; [ coreutils mantis gawk vault-bin gnused ])
    }"

    [ $# -eq 1 ] || { echo "One argument is required. Pass the number of keys to generate."; exit 1; }

    desired="$1"

    echo "generating $desired keys"

    for count in $(seq "$desired"); do
      keyFile="secrets/mantis-$count.key"
      secretKeyPath="kv/nomad-cluster/testnet/mantis-$count/secret-key"
      hashKeyPath="kv/nomad-cluster/testnet/mantis-$count/enode-hash"

      hashKey="$(vault kv get -field value "$hashKeyPath" || true)"

      if [ -z "$hashKey" ]; then
        if [ -s "$keyFile" ]; then
          echo "Uploading existing key from $keyFile to Vault"

          hashKey="$(tail -1 "$keyFile")"
          vault kv put "$hashKeyPath" "value=$hashKey"

          secretKey="$(head -1 "$keyFile")"
          vault kv put "$secretKeyPath" "value=$secretKey"
        else
          echo "Generating key in $keyFile and uploading to Vault"

          eckeygen -Dconfig.file=${final.mantis}/conf/mantis.conf > "$keyFile"

          hashKey="$(tail -1 "$keyFile")"
          vault kv put "$hashKeyPath" "value=$hashKey"

          secretKey="$(head -1 "$keyFile")"
          vault kv put "$secretKeyPath" "value=$secretKey"
        fi
      else
        echo "Downloading key for $keyFile from Vault"
        secretKey="$(vault kv get -field value "$secretKeyPath")"
        echo "$secretKey" > "$keyFile"
        echo "$hashKey" >> "$keyFile"
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

  nixosConfigurations =
    self.inputs.bitte.legacyPackages.${system}.mkNixosConfigurations
    final.clusters;

  clusters = self.inputs.bitte.legacyPackages.${system}.mkClusters {
    root = ./clusters;
    inherit self system;
  };

  inherit (self.inputs.bitte.legacyPackages.${system})
    vault-bin mkNomadJob mkNomadTaskSandbox terraform-with-plugins
    systemdSandbox nixFlakes nomad consul consul-template bitte-tokens;

  nomadJobs = let
    jobsDir = ./jobs;
    contents = builtins.readDir jobsDir;
    toImport = name: type: type == "regular" && lib.hasSuffix ".nix" name;
    fileNames = builtins.attrNames (lib.filterAttrs toImport contents);
    imported = lib.forEach fileNames
      (fileName: final.callPackage (jobsDir + "/${fileName}") { });
  in lib.foldl' lib.recursiveUpdate { } imported;
}
