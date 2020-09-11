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
    rev = "0ebe794e2fe20b877e6c96c4e825b73c4e6668d7";
    submodules = true;
  };

  mantis = import final.mantis-source {
    inherit system;
  };

  nomadJobs = final.callPackage ./jobs/mantis.nix { };

  devShell = prev.mkShell {
    # for bitte-cli
    LOG_LEVEL = "debug";

    buildInputs = [
      final.bitte
      final.terraform-with-plugins
      prev.sops
      final.vault-bin
      final.glibc
      final.gawk
      final.openssl
      final.cfssl
      final.nixfmt
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
    systemdSandbox nixFlakes;
}
