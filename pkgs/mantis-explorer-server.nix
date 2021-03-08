{ lib, writeBashBinChecked, nginx, coreutils, mantis-explorer }:
writeBashBinChecked "mantis-explorer-server" ''
  export PATH="${lib.makeBinPath [ nginx coreutils ]}"
  mkdir -p /var/cache/nginx
  ln -s ${mantis-explorer} /mantis-explorer
  exec nginx "$@"
''
