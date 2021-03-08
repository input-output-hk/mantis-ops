#!/usr/bin/env bash

[ $# -eq 3 ] || {
  echo "Three arguments are required. Pass the prefix, the number of mantis keys to generate and the number of OBFT keys to generate.";
  exit 1;
}

set -exuo pipefail

tmpdir="$(mktemp -d)"

set +e

read -r -d '' genesis <<JSON
{
  "extraData": "0x00",
  "nonce": "0x0000000000000042",
  "gasLimit": "0x7A1200",
  "difficulty": "0xF4240",
  "ommersHash" : "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
  "timestamp": "0x5FA34080",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "alloc": {}
}
JSON

read -r -d '' mantisConfigHocon <<"HOCON"
logging = {
  json-output = false
  logs-dir = "${tmpdir}"
}

mantis = {
  testmode = true
  consensus.mining-enabled = false
  blockchains.network = "testnet-internal-nomad"

  network.rpc = {
    http = {
      mode = "http"
      interface = "0.0.0.0"
      port = 8546
      cors-allowed-origins = "*"
    }
  }
}
HOCON

set -e

prefix="$1"
desired="$(($2 - 1))"
desiredObft="$(($3 - 1))"
mkdir -p secrets/"$prefix"

echo "generating $((desired + 1)) keys"

baseConf="$(dirname "$(dirname "$(readlink -f "$(which mantis)")")")/conf/base.conf"

echo "$mantisConfigHocon" > "$tmpdir/mantis-generate-keys.conf"
cat "$tmpdir/mantis-generate-keys.conf"
mantis "-Duser.home=$tmpdir" "-Dconfig.file=$baseConf" &
pid="$!"
on_exit() {
  kill "$pid"
  while kill -0 "$pid"; do
    sleep 0.1
  done
  rm -rf "$tmpdir"
}
trap on_exit EXIT

set +x
while ! nc -z 127.0.0.1 8546; do
	sleep 0.1 # wait for 1/10 of the second before check again
done
set -x

generateCoinbase() {
	curl -s http://127.0.0.1:8546 -H 'Content-Type: application/json' -d @<(cat <<EOF
		{
			"jsonrpc": "2.0",
			"method": "personal_importRawKey",
			"params": ["$1", ""],
			"id": 1
		}
EOF
	) | jq -e -r .result | sed 's/^0x//'
}

genesisPath="kv/nomad-cluster/$prefix/genesis"

nodes="$(seq -f "mantis-%g" 0 "$desired"; seq -f "obft-node-%g" 0 "$desiredObft")"
for node in $nodes; do
	mantisKeyFile="secrets/$prefix/mantis-$node.key"
	coinbaseFile="secrets/$prefix/$node.coinbase"
	coinbasePath="kv/nomad-cluster/$prefix/$node/coinbase"
	mantisSecretKeyPath="kv/nomad-cluster/$prefix/$node/secret-key"
	hashKeyPath="kv/nomad-cluster/$prefix/$node/enode-hash"
	accountPath="kv/nomad-cluster/$prefix/$node/account"

	obftKeyFile="secrets/$prefix/obft-$node.key"
	obftSecretKeyPath="kv/nomad-cluster/$prefix/$node/obft-secret-key"
	obftPublicKeyPath="kv/nomad-cluster/$prefix/$node/obft-public-key"

	account="$(vault kv get -field value "$accountPath" || true)"

	if [ -z "$account" ]; then
		if ! [ -s "$mantisKeyFile" ]; then
			echo "Generating key in $mantisKeyFile"
			until [ -s "$mantisKeyFile" ]; do
				echo "generating key..."
				eckeygen 1 | sed -r '/^\s*$/d' > "$mantisKeyFile"
			done
		fi

		echo "Uploading existing key from $mantisKeyFile to Vault"

		hashKey="$(tail -1 "$mantisKeyFile")"
		vault kv put "$hashKeyPath" "value=$hashKey"

		secretKey="$(head -1 "$mantisKeyFile")"
		vault kv put "$mantisSecretKeyPath" "value=$secretKey"

		coinbase="$(generateCoinbase "$secretKey")"
		vault kv put "$coinbasePath" "value=$coinbase"

		vault kv put "$accountPath" - < "$tmpdir"/.mantis/*/keystore/*"$coinbase"
	fi

	# OBFT-related keys for obft nodes
	# Note: a OBFT node needs *both* the mantis and OBFT keys to
	# work.
	if [[ "$node" =~ ^obft-node-[0-9]+$ ]]; then
		obftSecretKey="$(vault kv get -field value "$obftSecretKeyPath" || true)"
		if [ -z "$obftSecretKey" ]; then
			if ! [ -s "$obftKeyFile" ]; then
				echo "generating OBFT key..."
				until [ -s "$obftKeyFile" ]; do
						echo "generating key..."
						eckeygen 1 | sed -r '/^\s*$/d' > "$obftKeyFile"
				done
			fi

			echo "Uploading OBFT keys"
			obftPubKey="$(tail -1 "$obftKeyFile")"
			vault kv put "$obftPublicKeyPath" "value=$obftPubKey"
			obftSecretKey="$(head -1 "$obftKeyFile")"
			vault kv put "$obftSecretKeyPath" "value=$obftSecretKey"
		fi
	fi

done

# Every address gets 2^200 ETC
for count in $(seq 0 "$desired"); do
	updatedGenesis="$(
		echo "$genesis" \
		| jq --arg address "$(< "secrets/$prefix/mantis-$count.coinbase")" \
			'.alloc[$address] = {"balance": "1606938044258990275541962092341162602522202993782792835301376"}'
	)"
	genesis="$updatedGenesis"
done

echo "$genesis" | vault kv put "$genesisPath" -
