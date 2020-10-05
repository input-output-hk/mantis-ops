{ system, self }:
final: prev: {
  # we cannot specify mantis as a flake input due to:
  # * the branch having a slash
  # * the submodules syntax is broken
  # And here we cannot specify simply a branch since that's not reproducible,
  # so we use the commit instead.
  # The branch was `chore/update-sbt-add-nix`, for future reference.
  mantis-source = builtins.fetchGit {
    url = "https://github.com/input-output-hk/mantis";
    rev = "ba426525950f379ed5137c47e8f26851a4385a4d";
    ref = "develop";
    submodules = true;
  };

  mantis = import final.mantis-source { inherit system; };

  generate-mantis-keys = final.writeShellScriptBin "generate-mantis-keys" ''
    set -euo pipefail

    export PATH="${
      final.lib.makeBinPath
      (with final; [ coreutils mantis gawk vault-bin gnused ])
    }"

    if [ -s secrets/mantis-keys ]; then
      echo "secrets/mantis-keys already exists, remove it if you want to regenerate"
    else
      set -x
      eckeygen -Dconfig.file=${final.mantis}/conf/mantis.conf > secrets/mantis-keys
      eckeygen -Dconfig.file=${final.mantis}/conf/mantis.conf >> secrets/mantis-keys
      eckeygen -Dconfig.file=${final.mantis}/conf/mantis.conf >> secrets/mantis-keys
      eckeygen -Dconfig.file=${final.mantis}/conf/mantis.conf >> secrets/mantis-keys

      count=1
      for sk in $(awk 'NR % 2 { print }' secrets/mantis-keys); do
        vault kv put "kv/nomad-cluster/testnet/mantis-$count/secret-key" "value=$sk"
        count="$((count + 1))"
      done

      count=1
      for enode in $(awk '!(NR % 2) { print }' secrets/mantis-keys); do
        vault kv put "kv/nomad-cluster/testnet/mantis-$count/enode-hash" "value=$enode"
        count="$((count + 1))"
      done
    fi
  '';

  nomadJobs = final.callPackage ./jobs/mantis.nix { };

  devShell = prev.mkShell {
    # for bitte-cli
    LOG_LEVEL = "debug";

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
    ];
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
    systemdSandbox nixFlakes nomad consul consul-template;
}
