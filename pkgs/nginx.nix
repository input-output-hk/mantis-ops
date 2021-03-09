{ lib, writeBashBinChecked, nginx, coreutils, package, target }:
writeBashBinChecked "entrypoint" ''
  export PATH="${lib.makeBinPath [ nginx coreutils ]}"
  mkdir -p /var/cache/nginx
  ln -fs ${package} ${target}
  exec nginx -g 'error_log stderr;' "$@"
''
