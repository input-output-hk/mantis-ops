{ system }:
let
  src = builtins.fetchGit {
    url = "https://github.com/runtimeverification/iele-semantics.git";
    ref = "master";
    rev = "c5d2ddad799c7160418c0abb21a2be4ff1012736";
    submodules = true;
  };
  sources = import "${src}/nix/sources.nix" { };
  iele-semantics =
    import src { pkgs = import sources.nixpkgs { inherit system; }; };
in iele-semantics.kiele
