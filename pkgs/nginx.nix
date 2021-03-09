{ lib, writeBashBinChecked, nginx, coreutils, package, target }:
writeBashBinChecked "mantis-explorer-server" ''
  export PATH="${lib.makeBinPath [ nginx coreutils ]}"
  mkdir -p /var/cache/nginx
  ln -fs ${package} ${target}
  exec nginx -g 'error_log stderr;' "$@"
''
