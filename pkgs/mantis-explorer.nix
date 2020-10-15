{ src, web3Provider ? "/rpc/node", mkYarnPackage }:

mkYarnPackage {
  inherit src;

  patches = [ ./mantis-explorer.patch ];

  WEB3_PROVIDER = web3Provider;

  doCheck = true;
  checkPhase = "yarn test --coverage --ci";
  distPhase = "true";

  buildPhase = ''
    export HOME="$NIX_BUILD_TOP"
    yarn run build
  '';

  installPhase = ''
    mv deps/$pname/build $out
  '';
}
