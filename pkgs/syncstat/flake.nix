{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nmattia/naersk";
  };

  outputs = { self, nixpkgs, flake-utils, naersk }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";
        naersk-lib = naersk.lib."${system}";
      in rec {
        # `nix build`
        packages.syncstat = pkgs.symlinkJoin {
          name = "syncstat";
          paths = [
            pkgs.cacert
            (naersk-lib.buildPackage {
              pname = "syncstat";
              root = ./.;

              PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
              nativeBuildInputs = [ pkgs.pkgconfig ];
            })
          ];
        };
        defaultPackage = packages.syncstat;

        # `nix run`
        apps.syncstat = flake-utils.lib.mkApp { drv = packages.syncstat; };
        defaultApp = apps.syncstat;

        # `nix develop`
        devShell = pkgs.mkShell {
          RUST_BACKTRACE = "1";
          RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";

          nativeBuildInputs = with pkgs; [
            rustc
            cargo
            rust-analyzer
            clippy
            rustfmt
            rls
            pkgconfig
          ];
        };
      });
}
