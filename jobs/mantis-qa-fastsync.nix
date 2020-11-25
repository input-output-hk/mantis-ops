{ mkNomadJob, lib, mantis, mantis-source, mantis-faucet, mantis-faucet-source
, dockerImages }:
let
  # NOTE: Copy this file and change the next line if you want to start your own cluster!
  namespace = "mantis-qa-fastsync";

  genesisJson = {
    data = ''
      {{- with secret "kv/nomad-cluster/${namespace}/qa-genesis" -}}
      {{.Data.data | toJSON }}
      {{- end -}}
    '';
    changeMode = "restart";
    destination = "local/genesis.json";
  };

  templatesFor = { name ? null, mining-enabled ? false }:
    let secret = key: ''{{ with secret "${key}" }}{{.Data.data.value}}{{end}}'';
    in [
      {
        data = ''
          include "${mantis}/conf/app.conf"

          mantis {
            blockchains {
              network = "etc"

              etc {
                # Ethereum network identifier:
                # 1 - mainnet, 3 - ropsten, 7 - mordor
                network-id = 1

                # Possibility to set Proof of Work target time for testing purposes.
                # null means that the standard difficulty calculation rules are used
                pow-target-time = null

                # Frontier block number
                frontier-block-number = "0"

                # Homestead fork block number
                # Doc: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-2.md
                homestead-block-number = "1150000"

                # EIP-106 fork block number
                # Doc: https://github.com/ethereum/EIPs/issues/106
                eip106-block-number = "1000000000000000000"

                # EIP-150 fork block number
                # Doc: https://github.com/ethereum/EIPs/issues/150
                eip150-block-number = "2500000"

                # EIP-155 fork block number
                # Doc: https://github.com/ethereum/eips/issues/155
                # 3 000 000 following lead of existing clients implementation to maintain compatibility
                # https://github.com/paritytech/parity/blob/b50fb71dd1d29dfde2a6c7e1830447cf30896c31/ethcore/res/ethereum/classic.json#L15
                eip155-block-number = "3000000"

                # EIP-160 fork block number
                # Doc: https://github.com/ethereum/EIPs/issues/160
                eip160-block-number = "3000000"

                # EIP-161 fork block number (ETH Only)
                # Doc: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-161.md
                eip161-block-number = "1000000000000000000"

                # EIP-170 max code size (Enabled from Atlantis fork block number)
                # Doc: https://github.com/ethereum/EIPs/issues/170
                # null value indicates there's no max code size for the contract code
                # TODO improve this configuration format as currently it is not obvious that this is enabled only from some block number
                max-code-size = "24576"

                # Difficulty bomb pause block number
                # Doc: https://github.com/ethereumproject/ECIPs/blob/master/ECIPs/ECIP-1010.md
                difficulty-bomb-pause-block-number = "3000000"

                # Difficulty bomb continuation block number
                # Doc: https://github.com/ethereumproject/ECIPs/blob/master/ECIPs/ECIP-1010.md
                difficulty-bomb-continue-block-number = "5000000"

                # Difficulty bomb defusion block number
                # Doc: https://github.com/ethereumproject/ECIPs/blob/master/ECIPs/ECIP-1041.md
                difficulty-bomb-removal-block-number = "5900000"

                # Byzantium fork block number (ETH only)
                # https://github.com/ethereum/EIPs/blob/master/EIPS/eip-609.md
                byzantium-block-number = "1000000000000000000"

                # Atlantis fork block number (ETC only)
                # https://ecips.ethereumclassic.org/ECIPs/ecip-1054
                atlantis-block-number = "8772000"

                # Agharta fork block number (ETC only)
                # https://ecips.ethereumclassic.org/ECIPs/ecip-1056
                agharta-block-number = "9573000"

                # Phoenix fork block number (ETC only)
                # https://ecips.ethereumclassic.org/ECIPs/ecip-1088
                phoenix-block-number = "10500839"

                # Constantinople fork block number (ETH only)
                # https://github.com/ethereum/pm/issues/53
                constantinople-block-number = "1000000000000000000"

                # Petersburg fork block number (ETH only)
                # https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1716.md
                petersburg-block-number = "1000000000000000000"

                # Istanbul fork block number (ETH only)
                # https://eips.ethereum.org/EIPS/eip-1679
                istanbul-block-number = "1000000000000000000"

                # Proto-treasury fork block number (ETC only, but deactivated for now)
                # https://ecips.ethereumclassic.org/ECIPs/ecip-1098
                treasury-address = "0011223344556677889900112233445566778899"
                ecip1098-block-number = "1000000000000000000"

                # Checkpointing fork block number
                # https://ecips.ethereumclassic.org/ECIPs/ecip-1097
                # Has to be equal or greater than ecip1098-block-number
                ecip1097-block-number = "1000000000000000000"

                # Epoch calibration block number
                # https://ecips.ethereumclassic.org/ECIPs/ecip-1099
                ecip1099-block-number = "11700000"

                # DAO fork configuration (Ethereum HF/Classic split)
                # https://blog.ethereum.org/2016/07/20/hard-fork-completed/
                dao {
                  # DAO fork block number
                  fork-block-number = "1920000"

                  # The hash of the accepted DAO fork block
                  fork-block-hash = "94365e3a8c0b35089c1d1195081fe7489b528a84b22199c916180db8b28ade7f"

                  # Extra data to be put in fork block headers
                  block-extra-data = null

                  # number of blocks to place extra data after fork
                  block-extra-data-range = 10

                  # Address to send funds when draining
                  refund-contract-address = null

                  # List of accounts to be drained
                  drain-list = null
                }

                # Starting nonce of an empty account. Some networks (like Morden) use different values.
                account-start-nonce = "0"

                # The ID of the accepted chain
                chain-id = "0x3d"

                # Custom genesis JSON file path
                # null value indicates using default genesis definition that matches the main network
                custom-genesis-file = null

                # Monetary policy parameters
                # Doc: https://github.com/ethereumproject/ECIPs/blob/master/ECIPs/ECIP-1017.md
                monetary-policy {
                  # Block reward in the first era
                  first-era-block-reward = "5000000000000000000"

                  # Reduced block reward after Byzantium fork
                  first-era-reduced-block-reward = "3000000000000000000"

                  # Reduced block reward after Constantinople fork
                  first-era-constantinople-reduced-block-reward = "2000000000000000000"

                  # Monetary policy era duration in number of blocks
                  era-duration = 5000000

                  # Rate at which rewards get reduced in successive eras.
                  # Value in range [0.0, 1.0]
                  reward-reduction-rate = 0.2
                }

                # if 2 competing blocktree branches are equal in terms of total difficulty and this is set to true, then gas
                # consumed in those branches will be used to resolve the tie
                # this is currently only used in ETS blockchain tests
                gas-tie-breaker = false

                # if true, account storage will use Ethereum-specific format for storing keys/value in MPT (32 byte)
                # if false, generic storage for arbitrary length integers will be used
                eth-compatible-storage = true

                # Set of initial nodes
                bootstrap-nodes = [
                  "enode://d860a01f9722d78051619d1e2351aba3f43f943f6f00718d1b9baa4101932a1f5011f16bb2b1bb35db20d6fe28fa0bf09636d26a87d31de9ec6203eeedb1f666@18.138.108.67:30303",   // bootnode-aws-ap-southeast-1-001
                  "enode://22a8232c3abc76a16ae9d6c3b164f98775fe226f0917b0ca871128a74a8e9630b458460865bab457221f1d448dd9791d24c4e5d88786180ac185df813a68d4de@3.209.45.79:30303",     // bootnode-aws-us-east-1-001
                  "enode://ca6de62fce278f96aea6ec5a2daadb877e51651247cb96ee310a318def462913b653963c155a0ef6c7d50048bba6e6cea881130857413d9f50a621546b590758@34.255.23.113:30303",   // bootnode-aws-eu-west-1-001
                  "enode://279944d8dcd428dffaa7436f25ca0ca43ae19e7bcf94a8fb7d1641651f92d121e972ac2e8f381414b80cc8e5555811c2ec6e1a99bb009b3f53c4c69923e11bd8@35.158.244.151:30303",  // bootnode-aws-eu-central-1-001
                  "enode://8499da03c47d637b20eee24eec3c356c9a2e6148d6fe25ca195c7949ab8ec2c03e3556126b0d7ed644675e78c4318b08691b7b57de10e5f0d40d05b09238fa0a@52.187.207.27:30303",   // bootnode-azure-australiaeast-001
                  "enode://103858bdb88756c71f15e9b5e09b56dc1be52f0a5021d46301dbbfb7e130029cc9d0d6f73f693bc29b665770fff7da4d34f3c6379fe12721b5d7a0bcb5ca1fc1@191.234.162.198:30303", // bootnode-azure-brazilsouth-001
                  "enode://715171f50508aba88aecd1250af392a45a330af91d7b90701c436b618c86aaa1589c9184561907bebbb56439b8f8787bc01f49a7c77276c58c1b09822d75e8e8@52.231.165.108:30303",  // bootnode-azure-koreasouth-001
                  "enode://5d6d7cd20d6da4bb83a1d28cadb5d409b64edf314c0335df658c1a54e32c7c4a7ab7823d57c39b6a757556e68ff1df17c748b698544a55cb488b52479a92b60f@104.42.217.25:30303"   // bootnode-azure-westus-001
                ]

                # List of hex encoded public keys of Checkpoint Authorities
                checkpoint-public-keys = []
              }
            }
          }

          logging.json-output = true
          logging.logs-file = "logs"

          mantis.client-id = "${name}"
          mantis.sync.do-fast-sync = true
          mantis.consensus.mining-enabled = false
          mantis.network.discovery.scan-interval=15.seconds
          mantis.network.discovery.kademlia-bucket-size=16
          mantis.network.discovery.kademlia-alpha=16
          mantis.consensus.coinbase = "{{ with secret "kv/data/nomad-cluster/${namespace}/${name}/coinbase" }}{{ .Data.data.value }}{{ end }}"
          mantis.node-key-file = "{{ env "NOMAD_SECRETS_DIR" }}/secret-key"
          mantis.datadir = "/local/mantis"
          mantis.ethash.ethash-dir = "/local/ethash"
          mantis.metrics.enabled = true
          mantis.metrics.port = {{ env "NOMAD_PORT_metrics" }}
          mantis.network.rpc.http.interface = "0.0.0.0"
          mantis.network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}
          mantis.network.server-address.port = {{ env "NOMAD_PORT_server" }}
        '';
        destination = "local/mantis.conf";
        changeMode = "noop";
      }
      genesisJson
    ] ++ (lib.optional mining-enabled {
      data = ''
        ${secret "kv/data/nomad-cluster/${namespace}/${name}/secret-key"}
        ${secret "kv/data/nomad-cluster/${namespace}/${name}/enode-hash"}
      '';
      destination = "secrets/secret-key";
    });

  mkMantis = { name, resources, count ? 1, templates, serviceName, tags ? [ ]
    , meta ? { }, constraints ? [ ], requiredPeerCount, services ? { } }: {
      inherit count constraints;

      networks = [{
        ports = {
          metrics.to = 7000;
          rpc.to = 8000;
          server.to = 9000;
        };
      }];

      ephemeralDisk = {
        sizeMB = 10 * 1000;
        migrate = true;
        sticky = true;
      };

      reschedulePolicy = {
        attempts = 0;
        unlimited = true;
      };

      tasks.telegraf = {
        driver = "docker";

        vault.policies = [ "nomad-cluster" ];

        resources = {
          cpu = 100; # mhz
          memoryMB = 128;
        };

        config = {
          image = dockerImages.telegraf.id;
          args = [ "-config" "local/telegraf.config" ];

          labels = [{
            inherit namespace name;
            imageTag = dockerImages.telegraf.image.imageTag;
          }];

          logging = {
            type = "journald";
            config = [{
              tag = "${name}-telegraf";
              labels = "name,namespace,imageTag";
            }];
          };
        };

        templates = [{
          data = ''
            [agent]
            flush_interval = "10s"
            interval = "10s"
            omit_hostname = false

            [global_tags]
            client_id = "${name}"
            namespace = "${namespace}"

            [inputs.prometheus]
            metric_version = 1

            urls = [ "http://{{ env "NOMAD_ADDR_metrics" }}" ]

            [outputs.influxdb]
            database = "telegraf"
            urls = ["http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428"]
          '';

          destination = "local/telegraf.config";
        }];
      };

      services = lib.recursiveUpdate {
        "${serviceName}-prometheus" = {
          addressMode = "host";
          portLabel = "metrics";
          tags = [ "prometheus" namespace serviceName name mantis-source.rev ];
        };

        "${serviceName}-rpc" = {
          addressMode = "host";
          portLabel = "rpc";
          tags = [ "rpc" namespace serviceName name mantis-source.rev ];
        };

        ${serviceName} = {
          addressMode = "host";
          portLabel = "server";

          tags = [ "server" namespace serviceName mantis-source.rev ] ++ tags;

          meta = {
            inherit name;
            publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          } // meta;

          checks = [{
            type = "http";
            path = "/healthcheck";
            portLabel = "rpc";

            checkRestart = {
              limit = 5;
              grace = "300s";
              ignoreWarnings = false;
            };
          }];
        };
      } services;

      tasks.${name} = {
        inherit name resources templates;
        driver = "docker";
        vault.policies = [ "nomad-cluster" ];

        config = {
          image = dockerImages.mantis.id;
          args = [ "-Dconfig.file=running.conf" ];
          ports = [ "rpc" "server" "metrics" ];
          labels = [{
            inherit namespace name;
            imageTag = dockerImages.mantis.image.imageTag;
          }];

          logging = {
            type = "journald";
            config = [{
              tag = name;
              labels = "name,namespace,imageTag";
            }];
          };
        };

        restartPolicy = {
          interval = "30m";
          attempts = 10;
          delay = "1m";
          mode = "fail";
        };

        env = { REQUIRED_PEER_COUNT = toString requiredPeerCount; };
      };
    };

  mkMiner = { name, publicPort, requiredPeerCount ? 0, instanceId ? null }:
    lib.nameValuePair name (mkMantis {
      resources = {
        # For c5.2xlarge in clusters/mantis/testnet/default.nix, the url ref below
        # provides 3.4 GHz * 8 vCPU = 27.2 GHz max.
        # Mantis mainly uses only one core.
        # Allocating by vCPU or core quantity not yet available.
        # Ref: https://github.com/hashicorp/nomad/blob/master/client/fingerprint/env_aws.go
        cpu = 3400;
        memoryMB = 5 * 1024;
      };

      inherit name requiredPeerCount;
      templates = templatesFor {
        inherit name;
        mining-enabled = false;
      };

      serviceName = "${namespace}-mantis-miner";

      tags = [ "ingress" namespace name ];

      meta = {
        ingressHost = "${name}.mantis.ws";
        ingressPort = toString publicPort;
        ingressBind = "*:${toString publicPort}";
        ingressMode = "tcp";
        ingressServer = "_${namespace}-mantis-miner._${name}.service.consul";
      };
    });

  mkPassive = count:
    let name = "${namespace}-mantis-passive";
    in mkMantis {
      inherit name;
      serviceName = name;
      resources = {
        # For c5.2xlarge in clusters/mantis/testnet/default.nix, the url ref below
        # provides 3.4 GHz * 8 vCPU = 27.2 GHz max.  80% is 21760 MHz.
        # Allocating by vCPU or core quantity not yet available.
        # Ref: https://github.com/hashicorp/nomad/blob/master/client/fingerprint/env_aws.go
        cpu = 500;
        memoryMB = 5 * 1024;
      };

      tags = [ namespace "passive" "ingress" ];

      inherit count;

      requiredPeerCount = 0;

      services."${name}-rpc" = {
        addressMode = "host";
        tags = [ "rpc" "ingress" namespace name mantis-source.rev ];
        portLabel = "rpc";
        meta = {
          ingressHost = "${namespace}-explorer.mantis.ws";
          ingressMode = "http";
          ingressBind = "*:443";
          ingressIf =
            "{ path_beg -i /rpc/node } or { hdr(host) -i ${namespace}-explorer.mantis.ws } { path_beg -i /sockjs-node }";
          ingressServer = "_${name}-rpc._tcp.service.consul";
          ingressBackendExtra = ''
            option tcplog
            http-response set-header X-Server %s
            http-request set-path /
          '';
        };
      };

      templates = [
        {
          data = ''
            include "${mantis}/conf/app.conf"

            mantis {
              blockchains {
                network = "etc"

                etc {
                  # Ethereum network identifier:
                  # 1 - mainnet, 3 - ropsten, 7 - mordor
                  network-id = 1

                  # Possibility to set Proof of Work target time for testing purposes.
                  # null means that the standard difficulty calculation rules are used
                  pow-target-time = null

                  # Frontier block number
                  frontier-block-number = "0"

                  # Homestead fork block number
                  # Doc: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-2.md
                  homestead-block-number = "1150000"

                  # EIP-106 fork block number
                  # Doc: https://github.com/ethereum/EIPs/issues/106
                  eip106-block-number = "1000000000000000000"

                  # EIP-150 fork block number
                  # Doc: https://github.com/ethereum/EIPs/issues/150
                  eip150-block-number = "2500000"

                  # EIP-155 fork block number
                  # Doc: https://github.com/ethereum/eips/issues/155
                  # 3 000 000 following lead of existing clients implementation to maintain compatibility
                  # https://github.com/paritytech/parity/blob/b50fb71dd1d29dfde2a6c7e1830447cf30896c31/ethcore/res/ethereum/classic.json#L15
                  eip155-block-number = "3000000"

                  # EIP-160 fork block number
                  # Doc: https://github.com/ethereum/EIPs/issues/160
                  eip160-block-number = "3000000"

                  # EIP-161 fork block number (ETH Only)
                  # Doc: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-161.md
                  eip161-block-number = "1000000000000000000"

                  # EIP-170 max code size (Enabled from Atlantis fork block number)
                  # Doc: https://github.com/ethereum/EIPs/issues/170
                  # null value indicates there's no max code size for the contract code
                  # TODO improve this configuration format as currently it is not obvious that this is enabled only from some block number
                  max-code-size = "24576"

                  # Difficulty bomb pause block number
                  # Doc: https://github.com/ethereumproject/ECIPs/blob/master/ECIPs/ECIP-1010.md
                  difficulty-bomb-pause-block-number = "3000000"

                  # Difficulty bomb continuation block number
                  # Doc: https://github.com/ethereumproject/ECIPs/blob/master/ECIPs/ECIP-1010.md
                  difficulty-bomb-continue-block-number = "5000000"

                  # Difficulty bomb defusion block number
                  # Doc: https://github.com/ethereumproject/ECIPs/blob/master/ECIPs/ECIP-1041.md
                  difficulty-bomb-removal-block-number = "5900000"

                  # Byzantium fork block number (ETH only)
                  # https://github.com/ethereum/EIPs/blob/master/EIPS/eip-609.md
                  byzantium-block-number = "1000000000000000000"

                  # Atlantis fork block number (ETC only)
                  # https://ecips.ethereumclassic.org/ECIPs/ecip-1054
                  atlantis-block-number = "8772000"

                  # Agharta fork block number (ETC only)
                  # https://ecips.ethereumclassic.org/ECIPs/ecip-1056
                  agharta-block-number = "9573000"

                  # Phoenix fork block number (ETC only)
                  # https://ecips.ethereumclassic.org/ECIPs/ecip-1088
                  phoenix-block-number = "10500839"

                  # Constantinople fork block number (ETH only)
                  # https://github.com/ethereum/pm/issues/53
                  constantinople-block-number = "1000000000000000000"

                  # Petersburg fork block number (ETH only)
                  # https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1716.md
                  petersburg-block-number = "1000000000000000000"

                  # Istanbul fork block number (ETH only)
                  # https://eips.ethereum.org/EIPS/eip-1679
                  istanbul-block-number = "1000000000000000000"

                  # Proto-treasury fork block number (ETC only, but deactivated for now)
                  # https://ecips.ethereumclassic.org/ECIPs/ecip-1098
                  treasury-address = "0011223344556677889900112233445566778899"
                  ecip1098-block-number = "1000000000000000000"

                  # Checkpointing fork block number
                  # https://ecips.ethereumclassic.org/ECIPs/ecip-1097
                  # Has to be equal or greater than ecip1098-block-number
                  ecip1097-block-number = "1000000000000000000"

                  # Epoch calibration block number
                  # https://ecips.ethereumclassic.org/ECIPs/ecip-1099
                  ecip1099-block-number = "11700000"

                  # DAO fork configuration (Ethereum HF/Classic split)
                  # https://blog.ethereum.org/2016/07/20/hard-fork-completed/
                  dao {
                    # DAO fork block number
                    fork-block-number = "1920000"

                    # The hash of the accepted DAO fork block
                    fork-block-hash = "94365e3a8c0b35089c1d1195081fe7489b528a84b22199c916180db8b28ade7f"

                    # Extra data to be put in fork block headers
                    block-extra-data = null

                    # number of blocks to place extra data after fork
                    block-extra-data-range = 10

                    # Address to send funds when draining
                    refund-contract-address = null

                    # List of accounts to be drained
                    drain-list = null
                  }

                  # Starting nonce of an empty account. Some networks (like Morden) use different values.
                  account-start-nonce = "0"

                  # The ID of the accepted chain
                  chain-id = "0x3d"

                  # Custom genesis JSON file path
                  # null value indicates using default genesis definition that matches the main network
                  custom-genesis-file = null

                  # Monetary policy parameters
                  # Doc: https://github.com/ethereumproject/ECIPs/blob/master/ECIPs/ECIP-1017.md
                  monetary-policy {
                    # Block reward in the first era
                    first-era-block-reward = "5000000000000000000"

                    # Reduced block reward after Byzantium fork
                    first-era-reduced-block-reward = "3000000000000000000"

                    # Reduced block reward after Constantinople fork
                    first-era-constantinople-reduced-block-reward = "2000000000000000000"

                    # Monetary policy era duration in number of blocks
                    era-duration = 5000000

                    # Rate at which rewards get reduced in successive eras.
                    # Value in range [0.0, 1.0]
                    reward-reduction-rate = 0.2
                  }

                  # if 2 competing blocktree branches are equal in terms of total difficulty and this is set to true, then gas
                  # consumed in those branches will be used to resolve the tie
                  # this is currently only used in ETS blockchain tests
                  gas-tie-breaker = false

                  # if true, account storage will use Ethereum-specific format for storing keys/value in MPT (32 byte)
                  # if false, generic storage for arbitrary length integers will be used
                  eth-compatible-storage = true

                  # Set of initial nodes
                  bootstrap-nodes = [
                    "enode://d860a01f9722d78051619d1e2351aba3f43f943f6f00718d1b9baa4101932a1f5011f16bb2b1bb35db20d6fe28fa0bf09636d26a87d31de9ec6203eeedb1f666@18.138.108.67:30303",   // bootnode-aws-ap-southeast-1-001
                    "enode://22a8232c3abc76a16ae9d6c3b164f98775fe226f0917b0ca871128a74a8e9630b458460865bab457221f1d448dd9791d24c4e5d88786180ac185df813a68d4de@3.209.45.79:30303",     // bootnode-aws-us-east-1-001
                    "enode://ca6de62fce278f96aea6ec5a2daadb877e51651247cb96ee310a318def462913b653963c155a0ef6c7d50048bba6e6cea881130857413d9f50a621546b590758@34.255.23.113:30303",   // bootnode-aws-eu-west-1-001
                    "enode://279944d8dcd428dffaa7436f25ca0ca43ae19e7bcf94a8fb7d1641651f92d121e972ac2e8f381414b80cc8e5555811c2ec6e1a99bb009b3f53c4c69923e11bd8@35.158.244.151:30303",  // bootnode-aws-eu-central-1-001
                    "enode://8499da03c47d637b20eee24eec3c356c9a2e6148d6fe25ca195c7949ab8ec2c03e3556126b0d7ed644675e78c4318b08691b7b57de10e5f0d40d05b09238fa0a@52.187.207.27:30303",   // bootnode-azure-australiaeast-001
                    "enode://103858bdb88756c71f15e9b5e09b56dc1be52f0a5021d46301dbbfb7e130029cc9d0d6f73f693bc29b665770fff7da4d34f3c6379fe12721b5d7a0bcb5ca1fc1@191.234.162.198:30303", // bootnode-azure-brazilsouth-001
                    "enode://715171f50508aba88aecd1250af392a45a330af91d7b90701c436b618c86aaa1589c9184561907bebbb56439b8f8787bc01f49a7c77276c58c1b09822d75e8e8@52.231.165.108:30303",  // bootnode-azure-koreasouth-001
                    "enode://5d6d7cd20d6da4bb83a1d28cadb5d409b64edf314c0335df658c1a54e32c7c4a7ab7823d57c39b6a757556e68ff1df17c748b698544a55cb488b52479a92b60f@104.42.217.25:30303"   // bootnode-azure-westus-001
                  ]

                  # List of hex encoded public keys of Checkpoint Authorities
                  checkpoint-public-keys = []
                }
              }
            }

            logging.json-output = true
            logging.logs-file = "logs"

            mantis.client-id = "${name}"
            mantis.sync.do-fast-sync = true
            mantis.consensus.mining-enabled = false
            mantis.network.discovery.scan-interval=15.seconds
            mantis.network.discovery.kademlia-bucket-size=16
            mantis.network.discovery.kademlia-alpha=16
            mantis.datadir = "/local/mantis"
            mantis.ethash.ethash-dir = "/local/ethash"
            mantis.metrics.enabled = true
            mantis.metrics.port = {{ env "NOMAD_PORT_metrics" }}
            mantis.network.rpc.http.interface = "0.0.0.0"
            mantis.network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}
            mantis.network.server-address.port = {{ env "NOMAD_PORT_server" }}
          '';
          changeMode = "restart";
          destination = "local/mantis.conf";
        }
        genesisJson
      ];
    };

  amountOfMiners = 3;

  miners = lib.forEach (lib.range 1 amountOfMiners) (num: {
    name = "mantis-${toString num}";
    requiredPeerCount = 0;
    publicPort = 9000 + num; # routed through haproxy/ingress
  });

  explorer = let name = "${namespace}-explorer";
  in {
    services."${name}" = {
      addressMode = "host";
      portLabel = "http";

      tags = [ "ingress" namespace "explorer" name ];

      meta = {
        inherit name;
        publicIp = "\${attr.unique.platform.aws.public-ipv4}";
        ingressHost = "${name}.mantis.ws";
        ingressMode = "http";
        ingressBind = "*:443";
        ingressIf =
          "! { path_beg -i /rpc/node } ! { path_beg -i /sockjs-node }";
        ingressServer = "_${name}._tcp.service.consul";
        ingressBackendExtra = ''
          http-response set-header X-Server %s
        '';
      };

      checks = [{
        type = "http";
        path = "/";
        portLabel = "http";

        checkRestart = {
          limit = 5;
          grace = "300s";
          ignoreWarnings = false;
        };
      }];
    };

    networks = [{ ports = { http.to = 8080; }; }];

    tasks.explorer = {
      inherit name;
      driver = "docker";

      resources = {
        cpu = 100; # mhz
        memoryMB = 128;
      };

      config = {
        image = dockerImages.mantis-explorer-server.id;
        ports = [ "http" ];
        labels = [{
          inherit namespace name;
          imageTag = dockerImages.mantis-explorer-server.image.imageTag;
        }];

        logging = {
          type = "journald";
          config = [{
            tag = name;
            labels = "name,namespace,imageTag";
          }];
        };
      };
    };
  };

  faucetName = "${namespace}-mantis-faucet";
  faucet = {
    networks = [{
      ports = {
        metrics.to = 7000;
        rpc.to = 8000;
      };
    }];

    services = {
      "${faucetName}" = {
        addressMode = "host";
        portLabel = "rpc";
        task = "faucet";

        tags =
          [ "ingress" namespace "faucet" faucetName mantis-faucet-source.rev ];

        meta = {
          name = faucetName;
          publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          ingressHost = "${faucetName}.mantis.ws";
          ingressBind = "*:443";
          ingressMode = "http";
          ingressServer = "_${faucetName}._tcp.service.consul";
        };

        # FIXME: this always returns FaucetUnavailable
        # checks = [{
        #   taskName = "faucet";
        #   type = "script";
        #   name = "faucet_health";
        #   command = "healthcheck";
        #   interval = "60s";
        #   timeout = "5s";
        #   portLabel = "rpc";

        #   checkRestart = {
        #     limit = 5;
        #     grace = "300s";
        #     ignoreWarnings = false;
        #   };
        # }];
      };

      "${faucetName}-prometheus" = {
        addressMode = "host";
        portLabel = "metrics";
        tags = [
          "prometheus"
          namespace
          "faucet"
          faucetName
          mantis-faucet-source.rev
        ];
      };
    };

    tasks.faucet = {
      name = "faucet";
      driver = "docker";

      vault.policies = [ "nomad-cluster" ];

      resources = {
        cpu = 100;
        memoryMB = 1024;
      };

      config = {
        image = dockerImages.mantis-faucet.id;
        args = [ "-Dconfig.file=running.conf" ];
        ports = [ "rpc" "metrics" ];
        labels = [{
          inherit namespace;
          name = "faucet";
          imageTag = dockerImages.mantis-faucet.image.imageTag;
        }];

        logging = {
          type = "journald";
          config = [{
            tag = "faucet";
            labels = "name,namespace,imageTag";
          }];
        };
      };

      templates = let
        secret = key: ''{{ with secret "${key}" }}{{.Data.data.value}}{{end}}'';
      in [
        {
          data = ''
            faucet {
              # Base directory where all the data used by the faucet is stored
              datadir = "/local/mantis-faucet"

              # Wallet address used to send transactions from
              wallet-address =
                {{- with secret "kv/nomad-cluster/${namespace}/mantis-1/coinbase" -}}
                  "{{.Data.data.value}}"
                {{- end }}

              # Password to unlock faucet wallet
              wallet-password = ""

              # Path to directory where wallet key is stored
              keystore-dir = {{ env "NOMAD_SECRETS_DIR" }}/keystore

              # Transaction gas price
              tx-gas-price = 20000000000

              # Transaction gas limit
              tx-gas-limit = 90000

              # Transaction value
              tx-value = 1000000000000000000

              # Address of Ethereum node used to send the transaction
              rpc-address = {{- range service "mantis-1.${namespace}-mantis-miner-rpc" -}}
                  "http://{{ .Address }}:{{ .Port }}"
                {{- end }}

              # How often can a single IP address send a request
              min-request-interval = 0.minutes

              # Response time-out to get handler actor
              handler-timeout = 10.seconds

              # Response time-out from actor resolve
              response-timeout = 30.seconds

              # Supervisor with BackoffSupervisor pattern
              supervisor {
                min-backoff = 3.seconds
                # max-backoff = 30.seconds
                man-backoff = 30.seconds
                random-factor = 0.2
                auto-reset = 10.seconds
                attempts = 4
                delay = 0.1
              }

              # timeout for shutting down the ActorSystem
              shutdown-timeout = 15.seconds
            }

            logging {
              # Flag used to switch logs to the JSON format
              json-output = true

              # Logs directory
              #logs-dir = /local/mantis-faucet/logs

              # Logs filename
              logs-file = "logs"
            }

            mantis {
              network {
                rpc {
                  http {
                    # JSON-RPC mode
                    # Available modes are: http, https
                    # Choosing https requires creating a certificate and setting up 'certificate-keystore-path' and
                    # 'certificate-password-file'
                    # See: https://github.com/input-output-hk/mantis/wiki/Creating-self-signed-certificate-for-using-JSON-RPC-with-HTTPS
                    mode = "http"

                    # Whether to enable JSON-RPC HTTP(S) endpoint
                    enabled = true

                    # Listening address of JSON-RPC HTTP(S) endpoint
                    interface = "0.0.0.0"

                    # Listening port of JSON-RPC HTTP(S) endpoint
                    port = {{ env "NOMAD_PORT_rpc" }}

                    # Path to the keystore storing the certificates (used only for https)
                    # null value indicates HTTPS is not being used
                    certificate-keystore-path = null

                    # Type of certificate keystore being used
                    # null value indicates HTTPS is not being used
                    certificate-keystore-type = null

                    # File with the password used for accessing the certificate keystore (used only for https)
                    # null value indicates HTTPS is not being used
                    certificate-password-file = null

                    # Domains allowed to query RPC endpoint. Use "*" to enable requests from
                    # any domain.
                    cors-allowed-origins = "*"
                  }

                  ipc {
                    # Whether to enable JSON-RPC over IPC
                    enabled = false

                    # Path to IPC socket file
                    socket-file = "/local/mantis-faucet/faucet.ipc"
                  }

                  # Enabled JSON-RPC APIs over the JSON-RPC endpoint
                  apis = "faucet"
                }
              }
            }
          '';
          changeMode = "restart";
          destination = "local/faucet.conf";
        }
        genesisJson
        {
          data = ''
            {{- with secret "kv/data/nomad-cluster/${namespace}/mantis-1/account" -}}
            {{.Data.data | toJSON }}
            {{- end -}}
          '';
          destination = "secrets/account";
        }
        {
          data = ''
            COINBASE={{- with secret "kv/data/nomad-cluster/${namespace}/mantis-1/coinbase" -}}{{ .Data.data.value }}{{- end -}}
          '';
          destination = "secrets/env";
          env = true;
        }
      ];
    };

    tasks.telegraf = {
      driver = "docker";

      vault.policies = [ "nomad-cluster" ];

      resources = {
        cpu = 100; # mhz
        memoryMB = 128;
      };

      config = {
        image = dockerImages.telegraf.id;
        args = [ "-config" "local/telegraf.config" ];

        labels = [{
          inherit namespace;
          name = "faucet";
          imageTag = dockerImages.telegraf.image.imageTag;
        }];

        logging = {
          type = "journald";
          config = [{
            tag = "faucet-telegraf";
            labels = "name,namespace,imageTag";
          }];
        };
      };

      templates = [{
        data = ''
          [agent]
          flush_interval = "10s"
          interval = "10s"
          omit_hostname = false

          [global_tags]
          client_id = "faucet"
          namespace = "${namespace}"

          [inputs.prometheus]
          metric_version = 1

          urls = [ "http://{{ env "NOMAD_ADDR_metrics" }}" ]

          [outputs.influxdb]
          database = "telegraf"
          urls = ["http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428"]
        '';

        destination = "local/telegraf.config";
      }];
    };
  };
in {
  "${namespace}-mantis" = mkNomadJob "mantis" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    update = {
      maxParallel = 1;
      # healthCheck = "checks"
      minHealthyTime = "30s";
      healthyDeadline = "5m";
      progressDeadline = "10m";
      autoRevert = false;
      autoPromote = false;
      canary = 0;
      stagger = "30s";
    };

    taskGroups = (lib.listToAttrs (map mkMiner miners)) // {
      passive = mkPassive 1;
    };
  };

  "${namespace}-mantis-explorer" = mkNomadJob "explorer" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    taskGroups.explorer = explorer;
  };

  "${faucetName}" = mkNomadJob "faucet" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    taskGroups.faucet = faucet;
  };
}

// (import ./mantis-active-gen.nix {
  inherit mkNomadJob dockerImages;
  namespace = "mantis-qa-fastsync";
})
