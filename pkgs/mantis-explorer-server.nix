{ removeReferencesTo, inclusive, pkgconfig, openssl, crystal }:
crystal.buildCrystalPackage {
  pname = "mantis-explorer-server";
  version = "0.0.1";
  format = "crystal";

  src = inclusive ./. [ ./mantis-explorer-server.cr ];

  nativeBuildInputs = [ removeReferencesTo ];
  buildInputs = [ openssl pkgconfig ];

  postInstall = ''
    remove-references-to -t ${crystal.lib} $out/bin/*
  '';

  crystalBinaries.mantis-explorer-server = {
    src = "mantis-explorer-server.cr";
    options = [ "--verbose" "--release" ];
  };
}
