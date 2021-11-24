#!/bin/sh

[ $DIRENV_IN_ENVRC = 1 ] && exit
[ $NO_CACHE_UPLOAD = 1 ] && exit

set -eux
set -f # disable globbing
export IFS=' '

echo "Signing paths" $OUT_PATHS
nix store sign --key-file secrets/nix-secret-key-file $OUT_PATHS
echo "Uploading paths" $OUT_PATHS
exec nix copy --to 's3://iohk-mantis-kevm/infra/binary-cache/?region=eu-west-1' $OUT_PATHS
