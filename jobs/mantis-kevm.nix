{ mkNomadJob, domain, lib, mantis, mantis-source, mantis-faucet
, mantis-faucet-source, morpho-node, morpho-source, dockerImages
, mantis-explorer }:
let
  # NOTE: Copy this file and change the next line if you want to start your own cluster!
  namespace = "mantis-kevm";
  datacenters = [ "us-east-2" "eu-west-1" "eu-central-1" ];

  vault = {
    policies = [ "nomad-cluster" ];
    changeMode = "noop";
  };

  genesisJson = {
    data = ''
      {{- with secret "kv/nomad-cluster/${namespace}/genesis" -}}
      {{.Data.data | toJSON }}
      {{- end -}}
    '';
    changeMode = "restart";
    destination = "local/genesis.json";
  };

  config = { name, publicDiscoveryPort ? null, miningEnabled, ... }: ''
    logging {
      # Flag used to switch logs to the JSON format
      json-output = false

      # Logs directory
      logs-dir = /local/logs

      # Logs filename
      logs-file = /local/logs/log
    }

    mantis {
      # Optionally augment the client ID sent in Hello messages.
      client-identity = null

      # Version string (reported by an RPC method)
      client-version = "mantis/v2.0"

      # Base directory where all the data used by the node is stored, including blockchain data and private keys
      datadir = ''${user.home}"/.mantis/"''${mantis.blockchains.network}

      # The unencrypted private key of this node
      node-key-file = ''${mantis.datadir}"/node.key"

      # timeout for shutting down the ActorSystem
      shutdown-timeout = "15.seconds"

      # Whether to run Mantis in test mode (similar to --test flag in cpp-ethereum).
      # When set, test validators and consensus are used by this node.
      # It also enables test_ RPC endpoints.
      testmode = false

      # one of the algorithms defined here:
      # https://docs.oracle.com/javase/8/docs/technotes/guides/security/StandardNames.html#SecureRandom
      # Uncomment this to specify, otherwise use the default implementation
      # secure-random-algo = "NativePRNG"

      keyStore {
        # Keystore directory: stores encrypted private keys of accounts managed by this node
        keystore-dir = ''${mantis.datadir}"/keystore"

        # Enforces minimal length for passphrase of this keystore
        minimal-passphrase-length = 7

        # Allows possibility for no passphrase
        # If passphrase is set it must be greater than minimal-passphrase-length
        allow-no-passphrase = true
      }

      network {
        # Ethereum protocol version
        # Supported versions:
        # 63, 64 (experimental version which enables usage of messages with checkpointing information. In the future after ETCM-355, ETCM-356, it will be 66 probably)
        protocol-version = 63

        server-address {
          # Listening interface for Ethereum protocol connections
          interface = "0.0.0.0"

          # Listening port for Ethereum protocol connections
          port = 9076
        }

        discovery {

          # Turn discovery of/off
          discovery-enabled = true

          # Externally visible hostname or IP.
          host = null

          # Listening interface for discovery protocol
          interface = "0.0.0.0"

          # Listening port for discovery protocol
          port = 30303

          # If true, the node considers the bootstrap and the previously persisted nodes
          # as already discovered and uses them as peer candidates to get blocks from.
          # Otherwise it enroll with the bootstrap nodes and gradually discover the
          # network every time we start, eventually serving candidates.
          #
          # Useful if discovery has problem, as the node can start syncing with the
          # bootstraps straight away.
          #
          # Note that setting reuse-known-nodes and discovery-enabled to false at the
          # same time would mean the node would have no peer candidates at all.
          reuse-known-nodes = true

          # Scan interval for discovery
          scan-interval = 1.minutes

          # Discovery message expiration time
          message-expiration = 1.minute

          # Maximum amount a message can be expired by,
          # accounting for possible discrepancies between nodes' clocks.
          max-clock-drift = 15.seconds

          # Maximum number of peers in each k-bucket.
          kademlia-bucket-size = 16

          # Timeout for individual requests like Ping.
          request-timeout = 1.seconds

          # Timeout to collect all possible responses for a FindNode request.
          kademlia-timeout = 2.seconds

          # Level of concurrency during lookups and enrollment.
          kademlia-alpha = 3

          # Maximum number of messages in the queue associated with a UDP channel.
          channel-capacity = 100
        }

        known-nodes {
          # How often known nodes updates are persisted to disk
          persist-interval = 20.seconds

          # Maximum number of persisted nodes
          max-persisted-nodes = 200
        }

        peer {
          # Retry delay for failed attempt at connecting to a peer
          connect-retry-delay = 5 seconds

          # Maximum number of reconnect attempts after the connection has been initiated.
          # After that, the connection will be dropped until its initiated again (eg. by peer discovery)
          connect-max-retries = 1

          disconnect-poison-pill-timeout = 5 seconds

          wait-for-hello-timeout = 3 seconds

          wait-for-status-timeout = 30 seconds

          wait-for-chain-check-timeout = 15 seconds

          wait-for-handshake-timeout = 3 seconds

          wait-for-tcp-ack-timeout = 5 seconds

          # Maximum block headers in a single response message (as a blockchain host)
          max-blocks-headers-per-message = 100

          # Maximum block bodies in a single response message (as a blockchain host)
          max-blocks-bodies-per-message = 100

          # Maximum transactions receipts in a single response message (as a blockchain host)
          max-receipts-per-message = 100

          # Maximum MPT components in a single response message (as a blockchain host)
          max-mpt-components-per-message = 200

          # Maximum number of peers this node can connect to
          max-outgoing-peers = 50

          # Maximum number of peers that can connect to this node
          max-incoming-peers = 50

          # Maximum number of peers that can be connecting to this node
          max-pending-peers = 20

          # Initial delay before connecting to nodes
          update-nodes-initial-delay = 5.seconds

          # Newly discovered nodes connect attempt interval
          update-nodes-interval = 30.seconds

          # Peer which disconnect during tcp connection becouse of too many peers will not be retried for this short duration
          short-blacklist-duration = 6.minutes

          # Peer which disconnect during tcp connection becouse of other reasons will not be retried for this long duration
          # other reasons include: timeout during connection, wrong protocol, incompatible network
          long-blacklist-duration = 30.minutes
        }

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
            interface = "localhost"

            # Listening port of JSON-RPC HTTP(S) endpoint
            port = 8546

            certificate = null
            #certificate {
            # Path to the keystore storing the certificates (used only for https)
            # null value indicates HTTPS is not being used
            #  keystore-path = "tls/mantisCA.p12"

            # Type of certificate keystore being used
            # null value indicates HTTPS is not being used
            #  keystore-type = "pkcs12"

            # File with the password used for accessing the certificate keystore (used only for https)
            # null value indicates HTTPS is not being used
            #  password-file = "tls/password"
            #}

            # Domains allowed to query RPC endpoint. Use "*" to enable requests from
            # any domain.
            cors-allowed-origins = []

            # Rate Limit for JSON-RPC requests
            # Limits the amount of request the same ip can perform in a given amount of time
            rate-limit {
              # If enabled, restrictions are applied
              enabled = false

              # Time that should pass between requests
              min-request-interval = 10.seconds

              # Size of stored timestamps for requests made from each ip
              latest-timestamp-cache-size = 1024
            }
          }

          ipc {
            # Whether to enable JSON-RPC over IPC
            enabled = false

            # Path to IPC socket file
            socket-file = ''${mantis.datadir}"/mantis.ipc"
          }

          # Enabled JSON-RPC APIs over the JSON-RPC endpoint
          # Available choices are: web3, eth, net, personal, mantis, test, iele, debug, qa, checkpointing
          apis = "eth,web3,net,iele"
          disabled-methods = [
            "iele_sendTransaction",
            "eth_accounts",
            "eth_sendTransaction",
            "eth_sign"
          ]

          # Maximum number of blocks for mantis_getAccountTransactions
          account-transactions-max-blocks = 1000

          net {
            peer-manager-timeout = 5.seconds
          }

          miner-active-timeout = 5.seconds
        }
      }

      txPool {
        # Maximum number of pending transaction kept in the pool
        tx-pool-size = 1000

        pending-tx-manager-query-timeout = 5.seconds

        transaction-timeout = 2.minutes

        # Used in mining (ethash)
        get-transaction-from-pool-timeout = 5.seconds
      }

      consensus {
        # Miner's coinbase address
        # Also used in non-Ethash consensus.
        coinbase = "0011223344556677889900112233445566778899"

        # Extra data to add to mined blocks
        header-extra-data = "mantis"

        # This determines how many parallel eth_getWork request we can handle, by storing the prepared blocks in a cache,
        # until a corresponding eth_submitWork request is received.
        #
        # Also used by the generic `BlockGenerator`.
        block-cashe-size = 30

        # See io.iohk.ethereum.consensus.Protocol for the available protocols.
        # Declaring the protocol here means that a more protocol-specific configuration
        # is pulled from the corresponding consensus implementation.
        # For example, in case of ethash, a section named `ethash` is used.
        # Available protocols: ethash, mocked, restricted-ethash
        # In case of mocked, remember to enable qa api
        protocol = ethash

        # If true then the consensus protocol uses this node for mining.
        # In the case of ethash PoW, this means mining new blocks, as specified by Ethereum.
        # In the general case, the semantics are due to the specific consensus implementation.
        mining-enabled = false

        # Whether or not as a miner we want to support the proto-treasury and send 20% of the block reward to it
        # If false then that 20% gets burned
        # Doesn't have any effect is ecip1098 is not yet activated
        treasury-opt-out = false

      }

      # This is the section dedicated to Ethash mining.
      # This consensus protocol is selected by setting `mantis.consensus.protocol = ethash`.
      ethash {
        # Maximum number of ommers kept in the pool
        ommers-pool-size = 30

        ommer-pool-query-timeout = 5.seconds

        ethash-dir = ''${user.home}"/.ethash"

        mine-rounds = 100000
      }

      blockchains {
        network = "testnet-internal-nomad"

        testnet-internal-nomad {
          # Ethereum network identifier:
          # 1 - mainnet, 3 - ropsten, 7 - mordor
          network-id = 42

          # Possibility to set Proof of Work target time for testing purposes.
          # null means that the standard difficulty calculation rules are used
          pow-target-time = 30 seconds

          # Frontier block number
          frontier-block-number = "0"

          # Homestead fork block number
          # Doc: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-2.md
          homestead-block-number = "0"

          # EIP-106 fork block number
          # Doc: https://github.com/ethereum/EIPs/issues/106
          eip106-block-number = "1000000000000000000"

          # EIP-150 fork block number
          # Doc: https://github.com/ethereum/EIPs/issues/150
          eip150-block-number = "0"

          # EIP-155 fork block number
          # Doc: https://github.com/ethereum/eips/issues/155
          # 3 000 000 following lead of existing clients implementation to maintain compatibility
          # https://github.com/paritytech/parity/blob/b50fb71dd1d29dfde2a6c7e1830447cf30896c31/ethcore/res/ethereum/classic.json#L15
          eip155-block-number = "0"

          # EIP-160 fork block number
          # Doc: https://github.com/ethereum/EIPs/issues/160
          eip160-block-number = "0"

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
          difficulty-bomb-pause-block-number = "0"

          # Difficulty bomb continuation block number
          # Doc: https://github.com/ethereumproject/ECIPs/blob/master/ECIPs/ECIP-1010.md
          difficulty-bomb-continue-block-number = "0"

          # Difficulty bomb defusion block number
          # Doc: https://github.com/ethereumproject/ECIPs/blob/master/ECIPs/ECIP-1041.md
          difficulty-bomb-removal-block-number = "0"

          # Byzantium fork block number (ETH only)
          # https://github.com/ethereum/EIPs/blob/master/EIPS/eip-609.md
          byzantium-block-number = "1000000000000000000"

          # Atlantis fork block number (ETC only)
          # https://ecips.ethereumclassic.org/ECIPs/ecip-1054
          atlantis-block-number = "0"

          # Agharta fork block number (ETC only)
          # https://ecips.ethereumclassic.org/ECIPs/ecip-1056
          agharta-block-number = "0"

          # Phoenix fork block number (ETC only)
          # https://ecips.ethereumclassic.org/ECIPs/ecip-1088
          phoenix-block-number = "0"

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
          treasury-address = "0358e65dfe67b350eb827ffa17a82e7bb5f4c0c6"
          ecip1098-block-number = "0"

          # Checkpointing fork block number
          # https://ecips.ethereumclassic.org/ECIPs/ecip-1097
          # Has to be equal or greater than ecip1098-block-number
          ecip1097-block-number = "0"

          # Epoch calibration block number
          # https://ecips.ethereumclassic.org/ECIPs/ecip-1099
          ecip1099-block-number = "1000000000000000000"

          # DAO fork configuration (Ethereum HF/Classic split)
          # https://blog.ethereum.org/2016/07/20/hard-fork-completed/
          dao = null

          # Starting nonce of an empty account. Some networks (like Morden) use different values.
          account-start-nonce = "0"

          # The ID of the accepted chain
          chain-id = "0x2A"

          # Custom genesis JSON file path
          # null value indicates using default genesis definition that matches the main network
          custom-genesis-file = "chains/testnet-internal-nomad-genesis.json"

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
          bootstrap-nodes = []

          # List of hex encoded public keys of Checkpoint Authorities
          checkpoint-public-keys = []

          # List of hex encoded public keys of miners which can extend chain (only used when using restricted-ethash consensus)
          # empty means that everybody can mine
          allowed-miners = []
        }
      }

      sync {
        # Whether to enable fast-sync
        do-fast-sync = true

        # Interval for updating peers during sync
        peers-scan-interval = 3.seconds

        # Duration for blacklisting a peer. Blacklisting reason include: invalid response from peer, response time-out, etc.
        # 0 value is a valid duration and it will disable blacklisting completely (which can be useful when all nodes are
        # are controlled by a single party, eg. private networks)
        blacklist-duration = 200.seconds

        # Retry interval when not having enough peers to start fast-sync
        start-retry-interval = 5.seconds

        # Retry interval for resuming fast sync after all connections to peers were lost
        # Also retry interval in regular sync: for picking blocks batch and retrying requests
        sync-retry-interval = 0.5 seconds

        # Response time-out from peer during sync. If a peer fails to respond within this limit, it will be blacklisted
        peer-response-timeout = 30.seconds

        # Interval for logging syncing status info
        print-status-interval = 30.seconds

        # How often to dump fast-sync status to disk. If the client is restarted, fast-sync will continue from this point
        persist-state-snapshot-interval = 1.minute

        # Maximum concurrent requests when in fast-sync mode
        max-concurrent-requests = 50

        # Requested number of block headers when syncing from other peers
        block-headers-per-request = 200

        # Requested number of block bodies when syncing from other peers
        block-bodies-per-request = 128

        # Max. number of blocks that are going to be imported in one batch
        blocks-batch-size = 50

        # Requested number of TX receipts when syncing from other peers
        receipts-per-request = 60

        # Requested number of MPT nodes when syncing from other peers
        nodes-per-request = 384

        # Minimum number of peers required to start fast-sync (by determining the pivot block)
        min-peers-to-choose-pivot-block = 3

        # Number of additional peers used to determine pivot block during fast-sync
        # Number of peers used to reach consensus = min-peers-to-choose-pivot-block + peers-to-choose-pivot-block-margin
        peers-to-choose-pivot-block-margin = 1

        # During fast-sync when most up to date block is determined from peers, the actual target block number
        # will be decreased by this value
        pivot-block-offset = 32

        # How often to query peers for new blocks after the top of the chain has been reached
        check-for-new-block-interval = 10.seconds

        # size of the list that keeps track of peers that are failing to provide us with mpt node
        # we switch them to download only blockchain elements
        fastsync-block-chain-only-peers-pool = 100

        # time between 2 consecutive requests to peer when doing fast sync, this is to prevent flagging us as spammer
        fastsync-throttle = 0.1 seconds

        # When we receive a branch that is not rooted in our chain (we don't have a parent for the first header), it means
        # we found a fork. To resolve it, we need to query the same peer for previous headers, to find a common ancestor.
        branch-resolution-request-size = 30

        # TODO investigate proper value to handle ETC reorgs correctly
        # threshold for storing non-main-chain blocks in queue.
        # if: current_best_block_number - block_number > max-queued-block-number-behind
        # then: the block will not be queued (such already queued blocks will be removed)
        max-queued-block-number-behind = 100

        # TODO investigate proper value to handle ETC reorgs correctly
        # threshold for storing non-main-chain blocks in queue.
        # if: block_number - current_best_block_number > max-queued-block-number-ahead
        # then: the block will not be queued (such already queued blocks will be removed)
        max-queued-block-number-ahead = 100

        # Maximum number of blocks, after which block hash from NewBlockHashes packet is considered ancient
        # and peer sending it is blacklisted
        max-new-block-hash-age = 20

        # Maximum number of hashes processed form NewBlockHashes packet
        max-new-hashes = 64

        # This a recovery mechanism for the issue of missing state nodes during blocks execution:
        # off - missing state node will result in an exception
        # on - missing state node will be redownloaded from a peer and block execution will be retried. This can repeat
        #      several times until block execution succeeds
        redownload-missing-state-nodes = on

        # See: https://github.com/ethereum/go-ethereum/pull/1889
        fast-sync-block-validation-k = 100
        fast-sync-block-validation-n = 2048
        fast-sync-block-validation-x = 24

        # Maxium difference beetween our target block and best possible target block (current best known block - offset)
        # This is to ensure that we start downloading our state as close as possible to top of the chain
        max-target-difference = 10

        # Maxium number of failure to update target block, this could happen when target block, or x blocks  after target
        # fail validation. Or when we keep getting old block from the network.
        maximum-target-update-failures = 5

        # Sets max number of blocks that can be stored in queue to import on fetcher side
        # Warning! This setting affects ability to go back in case of branch resolution so it should not be too low
        max-fetcher-queue-size = 1000

        # Expected size fo state sync bloom filter.
        # Current Size of ETC state trie is aroud 150M Nodes, so 200M is set to have some reserve
        # If the number of elements inserted into bloom filter would be significally higher that expected, then number
        # of false positives would rise which would degrade performance of state sync
        state-sync-bloom-filter-size = 200000000

        # Max number of mpt nodes held in memory in state sync, before saving them into database
        # 100k is around 60mb (each key-value pair has around 600bytes)
        state-sync-persist-batch-size = 100000

        # If new pivot block received from network will be less than fast sync current pivot block, the re-try to chose new
        # pivot will be scheduler after this time. Avarage block time in etc/eth is around 15s so after this time, most of
        # network peers should have new best block
        pivot-block-reschedule-interval = 15.seconds

        # If for most network peers, the following condition will be true:
        # (peer.bestKnownBlock - pivot-block-offset) - node.curentPivotBlock > max-pivot-age
        # it fast sync pivot block has become stale and it needs update
        max-pivot-block-age = 96
      }

      pruning {
        # Pruning mode that the application will use.
        #
        # - archive:  No pruning is performed
        # - basic:    reference count based pruning
        # - inmemory: reference count inmemory pruning
        #
        # After changing, please delete previous db before starting the client:
        #
        mode = "basic"

        # The amount of block history kept before pruning
        # Note: if fast-sync clients choose target block offset greater than this value, mantis may not be able to
        # correctly act as a fast-sync server
        history = 64
      }

      node-caching {
        # Maximum number of nodes kept in cache
        # Each key-value pair of nodeHash-Nodencode has around ~600bytes, so cache around ~250Mb equals to 400000 key-value pairs
        max-size = 400000


        # Time after which we flush all data in cache to underlying storage
        # This ensures that in case of quit we lose at most ~5 min of work
        max-hold-time = 5.minutes
      }

      inmemory-pruning-node-caching {
        # Maximum number of nodes kept in cache
        # Cache size rationale:
        # To in memory pruner make sense, cache should have size which enables to hold at
        # least `history * (avg number of state nodes per block)`.
        # Current estmates are that at the top of eth chain each block carries 10k states nodes.
        # so at the moment: 64 (current history) * 10000 = 640000
        # This is lower bound, but to be prepared for future or accomodate for larger block it is worth to have cache
        # a little bit larger.
        # Current number = 2 * lowerBound
        # Cache size in mb:
        # Each key-value pair of nodeHash-Nodencoded has around ~700bytes -
        # 600b - encoded mpt node (this is upper bound, as many nodes like leaf nodes, are less than 150)
        # 4b   - Int, number of references
        # 24b  - BigIng, blocknumber, value taken from visual vm
        # 32b  - Cache key, hash node encoded
        # All sums to 660b, but there is always overhead for java objects.
        # Taking that in to account cache of 1280000 object will require at most: 896mb. (but ussually much less)
        #
        max-size = 1280000


        # Time after which we flush all data in cache to underlying storage
        # This ensures that in case of quit we lose at most ~60 min of work
        max-hold-time = 60.minutes
      }

      db {
        rocksdb {
          # RocksDB data directory
          path = ''${mantis.datadir}"/rocksdb/"

          # Create DB data directory if it's missing
          create-if-missing = true

          # Should the DB raise an error as soon as it detects an internal corruption
          paranoid-checks = true

          # This ensures that only one thread will be occupied
          max-threads = 1

          # This ensures that only 32 open files can be accessed at once
          max-open-files = 32

          # Force checksum verification of all data that is read from the file system on behalf of a particular read
          verify-checksums = true

          # In this mode, size target of levels are changed dynamically based on size of the last level
          # https://rocksdb.org/blog/2015/07/23/dynamic-level.html
          level-compaction-dynamic-level-bytes = true

          # Approximate size of user data packed per block (16 * 1024)
          block-size = 16384

          # Amount of cache in bytes that will be used by RocksDB (32 * 1024 * 1024)
          block-cache-size = 33554432
        }

        # Define which database to use [rocksdb]
        data-source = "rocksdb"
      }

      filter {
        # Time at which a filter remains valid
        filter-timeout = 10.minutes

        filter-manager-query-timeout = 3.minutes
      }

      vm {
        # internal | external
        mode = "internal"

        external {
          # possible values are:
          # - iele: runs a binary provided at `executable-path` with `port` and `host` as arguments (`./executable-path $port $host`)
          # - kevm: runs a binary provided at `executable-path` with `port` and `host` as arguments (`./executable-path $port $host`)
          # - mantis: if `executable-path` is provided, it will run the binary with `port` and `host` as arguments
          #           otherwise mantis VM will be run in the same process, but acting as an external VM (listening at `host` and `port`)
          # - none: doesn't run anything, expect the VM to be started by other means
          vm-type = "mantis"

          # path to the executable - optional depending on the `vm-type` setting
          executable-path = "./bin/mantis-vm"

          host = "127.0.0.1"
          port = 8888
        }
      }

      metrics {
        # Set to `true` iff your deployment supports metrics collection.
        # We expose metrics using a Prometheus server
        # We default to `false` here because we do not expect all deployments to support metrics collection.
        enabled = false

        # The port for setting up a Prometheus server over localhost.
        port = 13798
      }

      async {
        ask-timeout = 100.millis

        dispatchers {
          block-forger {
            type = Dispatcher
            executor = "fork-join-executor"

            fork-join-executor {
              parallelism-min = 2
              parallelism-factor = 2.0
              parallelism-max = 8

              task-peeking-mode = "FIFO"
            }

            throughput = 5
          }
        }
      }
    }

    akka {
      loggers = ["akka.event.slf4j.Slf4jLogger"]
      loglevel = "DEBUG"
      logging-filter = "akka.event.slf4j.Slf4jLoggingFilter"
      logger-startup-timeout = 30s
      log-dead-letters = off

      coordinated-shutdown.phases {
        actor-system-terminate {
          timeout = 15 s
        }
      }
    }


    # DEBUGGING SETTING
    # Uncomment to enable non-standard mailbox for all actors
    # Mailbox will start logging actor path, when actor mailbox size will be bigger than `size-limit`
    # Useful when looking for memory leaks caused by unbounded mailboxes
    #
    # akka.actor.default-mailbox {
    #  mailbox-type = io.iohk.ethereum.logger.LoggingMailboxType
    #  size-limit = 10000
    # }

    # Bounded mailbox configured for SignedTransactionsFilterActor.
    # Actor is resposible for calculating sender for signed transaction which is heavy operation, and when there are many
    # peers it can easily overflow
    bounded-mailbox {
      mailbox-type = "akka.dispatch.NonBlockingBoundedMailbox"
      mailbox-capacity = 50000
    }

    akka.actor.mailbox.requirements {
      "akka.dispatch.BoundedMessageQueueSemantics" = bounded-mailbox
    }

    # separate threadpool for concurrent header validation
    validation-context {
      type = Dispatcher
      executor = "thread-pool-executor"
      thread-pool-executor {
        fixed-pool-size = 4
      }
      throughput = 1
    }

    logging {
      # Flag used to switch logs to the JSON format
      json-output = false

      # Logs directory
      logs-dir = ''${mantis.datadir}"/logs"

      # Logs filename
      logs-file = "mantis"
    }

    mantis {
      sync {
        # Fast sync is disabled, requires coordination to see if it affects our deployments if we turn this on
        do-fast-sync = false

        # All testnet members are assumed to be honest so blacklisting is turned off
        blacklist-duration = 0
      }

      pruning {
        # Pruning is disabled as it's an experimental feature for now
        mode = "archive"
      }

      consensus {
        coinbase = "0011223344556677889900112233445566778899" # has to be changed for each node
        mining-enabled = false
        protocol = "restricted-ethash"
      }

      vm {
        mode = "external"
        external {
          vm-type = "kevm"
          run-vm = true
          executable-path = "/bin/kevm-vm"
          host = "127.0.0.1"
          port = {{ env "NOMAD_PORT_vm" }}
        }
      }

      network {
        protocol-version = 64

        discovery {
          # We assume a fixed cluster, so `bootstrap-nodes` must not be empty
          discovery-enabled = false

          # Listening interface for discovery protocol
          interface = "0.0.0.0"
        }

        peer {
          # All testnet members are assumed to be honest so blacklisting is turned off
          short-blacklist-duration = 0
          long-blacklist-duration = 0

          wait-for-handshake-timeout = 15 seconds

        }

        rpc {
          http {
            # Listening address of JSON-RPC HTTP/HTTPS endpoint
            interface = "0.0.0.0"

            # Domains allowed to query RPC endpoint. Use "*" to enable requests from any domain.
            cors-allowed-origins = "*"
          }
        }
      }
    }

    mantis.blockchains.testnet-internal-nomad.bootstrap-nodes = [
      {{ range service "${namespace}-mantis-miner-server" -}}
        "enode://  {{- with secret (printf "kv/data/nomad-cluster/${namespace}/%s/enode-hash" .ServiceMeta.Name) -}}
          {{- .Data.data.value -}}
          {{- end -}}@{{ .Address }}:{{ .Port }}",
      {{ end -}}
    ]

    mantis.blockchains.testnet-internal-nomad.checkpoint-public-keys = [
      ${
        lib.concatMapStringsSep "," (x: ''
          {{- with secret "kv/data/nomad-cluster/${namespace}/obft-node-${
            toString x
          }/obft-public-key" -}}"{{- .Data.data.value -}}"{{end}}
        '') (lib.range 1 amountOfMorphoNodes)
      }
    ]

    mantis.consensus.mining-enabled = ${lib.boolToString miningEnabled}
    mantis.client-id = "${name}"
    ${lib.optionalString miningEnabled ''
      mantis.consensus.coinbase = "{{ with secret "kv/data/nomad-cluster/${namespace}/${name}/coinbase" }}{{ .Data.data.value }}{{ end }}"
      mantis.node-key-file = "{{ env "NOMAD_SECRETS_DIR" }}/secret-key"
    ''}
    mantis.datadir = "/local/mantis"
    mantis.ethash.ethash-dir = "/local/ethash"
    mantis.metrics.enabled = true
    mantis.metrics.port = {{ env "NOMAD_PORT_metrics" }}
    ${lib.optionalString (publicDiscoveryPort != null) ''
      mantis.network.discovery.discovery-enabled = true
      mantis.network.discovery.host = {{ with node "monitoring" }}"{{ .Node.Address }}"{{ end }}
      mantis.network.discovery.port = ${toString publicDiscoveryPort}
    ''}
    mantis.network.rpc.http.interface = "0.0.0.0"
    mantis.network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}
    mantis.network.server-address.port = {{ env "NOMAD_PORT_server" }}
    mantis.blockchains.testnet-internal-nomad.custom-genesis-file = "{{ env "NOMAD_TASK_DIR" }}/genesis.json"

    mantis.blockchains.testnet-internal-nomad.ecip1098-block-number = 0
    mantis.blockchains.testnet-internal-nomad.ecip1097-block-number = 0
  '';

  amountOfMorphoNodes = 5;

  morphoNodes = lib.forEach (lib.range 1 amountOfMorphoNodes) (n: {
    name = "obft-node-${toString n}";
    nodeNumber = n;
  });

  mkMorpho = { name, nodeNumber, nbNodes }: {
    services = {
      "${namespace}-morpho-node" = {
        portLabel = "morpho";

        tags = [ "morpho" namespace name morpho-source.rev ];
        meta = {
          inherit name;
          nodeNumber = builtins.toString nodeNumber;
        };
      };
    };

    ephemeralDisk = {
      sizeMB = 500;
      migrate = true;
      sticky = true;
    };

    networks = [{
      mode = "bridge";
      ports = {
        metrics.to = 7000;
        rpc.to = 8000;
        server.to = 9000;
        morpho.to = 3000;
        morphoPrometheus.to = 6000;
      };
    }];

    tasks.${name} = {
      inherit name vault;
      driver = "docker";
      env = { REQUIRED_PEER_COUNT = builtins.toString nbNodes; };

      templates = [
        {
          data = ''
            ApplicationName: morpho-checkpoint
            ApplicationVersion: 1
            CheckpointInterval: 4
            FedPubKeys:
            {{- range service "${namespace}-morpho-node" -}}
            {{- with secret (printf "kv/data/nomad-cluster/${namespace}/%s/obft-public-key" .ServiceMeta.Name) }}
                - {{ .Data.data.value -}}
                {{- end -}}
            {{- end }}
            LastKnownBlockVersion-Major: 0
            LastKnownBlockVersion-Minor: 2
            LastKnownBlockVersion-Alt: 0
            NetworkMagic: 12345
            NodeId: {{ index (split "-" "${name}") 2 }}
            NodePrivKeyFile: {{ env "NOMAD_SECRETS_DIR" }}/morpho-private-key
            NumCoreNodes: {{ len (service "${namespace}-morpho-node") }}
            PoWBlockFetchInterval: 5000000
            PoWNodeRpcUrl: http://127.0.0.1:{{ env "NOMAD_PORT_rpc" }}
            PrometheusPort: {{ env "NOMAD_PORT_morphoPrometheus" }}
            Protocol: MockedBFT
            RequiredMajority: {{ len (service "${namespace}-morpho-node") | divide 2 | add 1 }}
            RequiresNetworkMagic: RequiresMagic
            SecurityParam: 5
            SlotDuration: 5
            SnapshotsOnDisk: 60
            SnapshotInterval: 60
            SystemStart: "2020-11-17T00:00:00Z"
            TurnOnLogMetrics: True
            TurnOnLogging: True
            ViewMode: SimpleView
            minSeverity: Debug
            TracingVerbosity: NormalVerbosity
            setupScribes:
              - scKind: StdoutSK
                scFormat: ScText
                scName: stdout
            defaultScribes:
              - - StdoutSK
                - stdout
            setupBackends:
              - KatipBK
            defaultBackends:
              - KatipBK
            options:
              mapBackends:
          '';
          destination = "local/morpho-config.yaml";
          changeMode = "restart";
          splay = "15m";
        }
        {
          data = ''
            {{- with secret "kv/data/nomad-cluster/${namespace}/${name}/obft-secret-key" -}}
            {{- .Data.data.value -}}
            {{- end -}}
          '';
          destination = "secrets/morpho-private-key";
          changeMode = "restart";
          splay = "15m";
        }
        {
          data = ''
            [
              {{- range $index1, $service1 := service "${namespace}-morpho-node" -}}
              {{ if ne $index1 0 }},{{ end }}
                {
                  "nodeAddress": {
                  "addr": "{{ .Address }}",
                  "port": {{ .Port }},
                  "valency": 1
                  },
                  "nodeId": {{- index (split "-" .ServiceMeta.Name) 2 -}},
                  "producers": [
                  {{- range $index2, $service2 := service "${namespace}-morpho-node" -}}
                  {{ if ne $index2 0 }},{{ end }}
                    {
                        "addr": "{{ .Address }}",
                        "port": {{ .Port }},
                        "valency": 1
                    }
                  {{- end -}}
                  ]}
              {{- end }}
              ]
          '';
          destination = "local/morpho-topology.json";
          changeMode = "noop";
          splay = "15m";
        }
      ];

      config = {
        image = dockerImages.morpho;
        args = [ ];
        labels = [{
          inherit namespace name;
          imageTag = dockerImages.morpho.image.imageTag;
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
        interval = "10m";
        attempts = 10;
        delay = "30s";
        mode = "delay";
      };
    };

    tasks.telegraf = {
      driver = "docker";

      inherit vault;

      resources = {
        cpu = 100; # mhz
        memoryMB = 128;
      };

      config = {
        image = dockerImages.telegraf;
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

          urls = [
            "http://127.0.0.1:{{ env "NOMAD_PORT_morphoPrometheus" }}"
          ]

          [outputs.influxdb]
          database = "telegraf"
          urls = [ {{ with node "monitoring" }}"http://{{ .Node.Address }}:8428"{{ end }} ]
        '';

        destination = "local/telegraf.config";
      }];
    };

    tasks.telegraf-mantis = {
      driver = "docker";

      inherit vault;

      resources = {
        cpu = 100; # mhz
        memoryMB = 128;
      };

      config = {
        image = dockerImages.telegraf;
        args = [ "-config" "local/telegraf.config" ];

        labels = [{
          inherit namespace name;
          imageTag = dockerImages.telegraf.image.imageTag;
        }];

        logging = {
          type = "journald";
          config = [{
            tag = "${name}-telegraf-morpho";
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
          client_id = "${name}-mantis"
          namespace = "${namespace}"

          [inputs.prometheus]
          metric_version = 1

          urls = [ "http://127.0.0.1:{{ env "NOMAD_PORT_metrics" }}" ]

          [outputs.influxdb]
          database = "telegraf"
          urls = [ {{ with node "monitoring" }}"http://{{ .Node.Address }}:8428"{{ end }} ]
        '';

        destination = "local/telegraf.config";
      }];
    };
  };

  mkMantis = { name, resources, count ? 1, templates, serviceName, tags ? [ ]
    , serverMeta ? { }, meta ? { }, discoveryMeta ? { }, rpcMeta ? { }
    , requiredPeerCount, services ? { } }: {
      inherit count;

      networks = [{
        mode = "bridge";
        ports = {
          discovery.to = 2000;
          metrics.to = 3000;
          rpc.to = 4000;
          server.to = 5000;
          vm.to = 6000;
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

        inherit vault;

        resources = {
          cpu = 100; # mhz
          memoryMB = 128;
        };

        config = {
          image = dockerImages.telegraf;
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

            urls = [ "http://127.0.0.1:{{ env "NOMAD_PORT_metrics" }}" ]

            [outputs.influxdb]
            database = "telegraf"
            urls = [ {{ with node "monitoring" }}"http://{{ .Node.Address }}:8428"{{ end }} ]
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
          tags = [ "rpc" namespace serviceName name mantis-source.rev ] ++ tags;
          meta = {
            inherit name;
            publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          } // rpcMeta;
        };

        "${serviceName}-discovery" = {
          portLabel = "discovery";
          tags = [ "discovery" namespace serviceName name mantis-source.rev ]
            ++ tags;
          meta = {
            inherit name;
            publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          } // discoveryMeta;
        };

        "${serviceName}-server" = {
          portLabel = "server";
          tags = [ "server" namespace serviceName name mantis-source.rev ]
            ++ tags;
          meta = {
            inherit name;
            publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          } // serverMeta;
        };

        ${serviceName} = {
          addressMode = "host";
          portLabel = "server";

          tags = [ "server" namespace serviceName mantis-source.rev ] ++ tags;

          meta = {
            inherit name;
            publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          } // meta;
        };
      } services;

      tasks.${name} = {
        inherit name resources templates;
        driver = "docker";
        inherit vault;

        config = {
          image = dockerImages.mantis-kevm;
          args = [ "-Dconfig.file=running.conf" ];
          ports = [ "rpc" "server" "metrics" "vm" ];
          labels = [{
            inherit namespace name;
            imageTag = dockerImages.mantis-kevm.image.imageTag;
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

  mkMiner = { name, publicDiscoveryPort, publicServerPort, publicRpcPort
    , requiredPeerCount ? 0, instanceId ? null }:
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
      templates = [
        {
          data = config {
            inherit publicDiscoveryPort namespace name;
            miningEnabled = true;
          };
          changeMode = "noop";
          destination = "local/mantis.conf";
          splay = "15m";
        }
        {
          data = let
            secret = key:
              ''{{ with secret "${key}" }}{{.Data.data.value}}{{end}}'';
          in ''
            ${secret "kv/data/nomad-cluster/${namespace}/${name}/secret-key"}
            ${secret "kv/data/nomad-cluster/${namespace}/${name}/enode-hash"}
          '';
          destination = "secrets/secret-key";
          changeMode = "restart";
          splay = "15m";
        }
        {
          data = ''
            AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
            AWS_DEFAULT_REGION="us-east-1"
            AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
            MONITORING_ADDR="http://{{ with node "monitoring" }}{{ .Node.Address }}{{ end }}:9000"
            MONITORING_URL="http://{{ with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428/api/v1/query"
            DAG_NAME="full-R23-0000000000000000"
          '';
          env = true;
          destination = "secrets/env.txt";
          changeMode = "noop";
        }
        genesisJson
      ];

      serviceName = "${namespace}-mantis-miner";

      tags = [ "ingress" namespace name ];

      serverMeta = {
        ingressHost = "${name}.${domain}";
        ingressPort = toString publicServerPort;
        ingressBind = "*:${toString publicServerPort}";
        ingressMode = "tcp";
        ingressServer = "_${namespace}-mantis-miner._${name}.service.consul";
      };

      discoveryMeta = {
        ingressHost = "${name}.${domain}";
        ingressPort = toString publicDiscoveryPort;
        ingressBind = "*:${toString publicDiscoveryPort}";
        ingressMode = "tcp";
        ingressServer =
          "_${namespace}-mantis-miner._${name}-discovery.service.consul";
      };

      rpcMeta = {
        ingressHost = "${name}.${domain}";
        ingressPort = toString publicRpcPort;
        ingressBind = "*:443";
        ingressMode = "http";
        ingressServer =
          "_${namespace}-mantis-miner-rpc._${name}.service.consul";
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

      tags = [ namespace "passive" ];

      inherit count;

      requiredPeerCount = builtins.length miners;

      services."${name}-rpc" = {
        addressMode = "host";
        tags = [ "rpc" namespace name mantis-source.rev ];
        portLabel = "rpc";
      };

      templates = [
        {
          data = config {
            inherit namespace name;
            miningEnabled = false;
          };
          changeMode = "noop";
          destination = "local/mantis.conf";
          splay = "15m";
        }
        genesisJson
      ];
    };

  explorer = let name = "${namespace}-explorer";
  in {
    services."${name}" = {
      addressMode = "host";
      portLabel = "explorer";

      tags = [ "ingress" namespace "explorer" name ];

      meta = {
        inherit name;
        publicIp = "\${attr.unique.platform.aws.public-ipv4}";
        ingressHost = "explorer.${domain}";
        ingressMode = "http";
        ingressBind = "*:443";
        ingressServer = "_${name}._tcp.service.consul";
        ingressBackendExtra = ''
          http-response set-header X-Server %s
        '';
      };

      checks = [{
        type = "http";
        path = "/";
        portLabel = "explorer";

        checkRestart = {
          limit = 5;
          grace = "300s";
          ignoreWarnings = false;
        };
      }];
    };

    networks = [{
      mode = "bridge";
      ports = { explorer.to = 8080; };
    }];

    tasks.explorer = {
      inherit name;
      driver = "docker";

      resources = {
        cpu = 100; # mhz
        memoryMB = 128;
      };

      config = {
        image = dockerImages.mantis-explorer-server;
        args = [ "nginx" "-c" "/local/nginx.conf" ];
        ports = [ "explorer" ];
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

      templates = [{
        data = ''
          user nginx nginx;
          error_log /dev/stderr info;
          pid /dev/null;
          events {}
          daemon off;

          http {
            access_log /dev/stdout;

            upstream backend {
              least_conn;
              {{ range service "${namespace}-mantis-passive-rpc" }}
                server {{ .Address }}:{{ .Port }};
              {{ end }}
            }

            server {
              listen 8080;

              location / {
                root /mantis-explorer;
                index index.html;
                try_files $uri $uri/ /index.html;
              }

              location /rpc/node {
                proxy_pass http://backend/;
              }

              location /sockjs-node {
                proxy_pass http://backend/;
              }
            }
          }
        '';
        changeMode = "restart";
        destination = "local/nginx.conf";
      }];
    };
  };

  faucetName = "${namespace}-faucet";
  faucet = {
    networks = [{
      mode = "bridge";
      ports = {
        metrics.to = 7000;
        rpc.to = 8000;
        faucet-web.to = 8080;
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
          ingressHost = "faucet.${domain}";
          ingressBind = "*:443";
          ingressMode = "http";
          ingressServer = "_${faucetName}._tcp.service.consul";
          ingressBackendExtra = ''
            option forwardfor
            http-response set-header X-Server %s
          '';
          ingressFrontendExtra = ''
            reqidel ^X-Forwarded-For:.*
          '';
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

      "${faucetName}-web" = {
        addressMode = "host";
        portLabel = "faucet-web";
        tags =
          [ "ingress" namespace "faucet" faucetName mantis-faucet-source.rev ];
        meta = {
          name = faucetName;
          publicIp = "\${attr.unique.platform.aws.public-ipv4}";
          ingressHost = "${faucetName}-web.${domain}";
          ingressBind = "*:443";
          ingressMode = "http";
          ingressServer = "_${faucetName}-web._tcp.service.consul";
        };
      };
    };

    tasks.faucet = {
      name = "faucet";
      driver = "docker";

      inherit vault;

      resources = {
        cpu = 100;
        memoryMB = 1024;
      };

      config = {
        image = dockerImages.mantis-faucet;
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

              rpc-client {
                # Address of Ethereum node used to send the transaction
                rpc-address = {{- range service "mantis-1.${namespace}-mantis-miner-rpc" -}}
                    "http://{{ .Address }}:{{ .Port }}"
                  {{- end }}

                # certificate of Ethereum node used to send the transaction when use HTTP(S)
                certificate = null
                #certificate {
                # Path to the keystore storing the certificates (used only for https)
                # null value indicates HTTPS is not being used
                #  keystore-path = "tls/mantisCA.p12"

                # Type of certificate keystore being used
                # null value indicates HTTPS is not being used
                #  keystore-type = "pkcs12"

                # File with the password used for accessing the certificate keystore (used only for https)
                # null value indicates HTTPS is not being used
                #  password-file = "tls/password"
                #}

                # Response time-out from rpc client resolve
                timeout = 3.seconds
              }

              # How often can a single IP address send a request
              min-request-interval = 1.minute

              # Response time-out to get handler actor
              handler-timeout = 1.seconds

              # Response time-out from actor resolve
              actor-communication-margin = 1.seconds

              # Supervisor with BackoffSupervisor pattern
              supervisor {
                min-backoff = 3.seconds
                max-backoff = 30.seconds
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
              json-output = false

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

                    certificate = null
                    #certificate {
                    # Path to the keystore storing the certificates (used only for https)
                    # null value indicates HTTPS is not being used
                    #  keystore-path = "tls/mantisCA.p12"

                    # Type of certificate keystore being used
                    # null value indicates HTTPS is not being used
                    #  keystore-type = "pkcs12"

                    # File with the password used for accessing the certificate keystore (used only for https)
                    # null value indicates HTTPS is not being used
                    #  password-file = "tls/password"
                    #}

                    # Domains allowed to query RPC endpoint. Use "*" to enable requests from
                    # any domain.
                    cors-allowed-origins = "*"

                    # Rate Limit for JSON-RPC requests
                    # Limits the amount of request the same ip can perform in a given amount of time
                    rate-limit {
                      # If enabled, restrictions are applied
                      enabled = true

                      # Time that should pass between requests
                      # Reflecting Faucet Web UI configuration
                      # https://github.com/input-output-hk/mantis-faucet-web/blob/main/src/index.html#L18
                      min-request-interval = 24.hours

                      # Size of stored timestamps for requests made from each ip
                      latest-timestamp-cache-size = 1024
                    }
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
        genesisJson
      ];
    };

    tasks.faucet-web = {
      name = "faucet-web";
      driver = "docker";
      resources = {
        cpu = 100;
        memoryMB = 128;
      };
      config = {
        image = dockerImages.mantis-faucet-web;
        args = [ "nginx" "-c" "/local/nginx.conf" ];
        ports = [ "faucet-web" ];
        labels = [{
          inherit namespace;
          name = "faucet-web";
          imageTag = dockerImages.mantis-faucet-web.image.imageTag;
        }];

        logging = {
          type = "journald";
          config = [{
            tag = "faucet-web";
            labels = "name,namespace,imageTag";
          }];
        };
      };
      templates = [{
        data = ''
          user nginx nginx;
          error_log /dev/stdout info;
          pid /dev/null;
          events {}
          daemon off;

          http {
            access_log /dev/stdout;

            types {
              text/css         css;
              text/javascript  js;
              text/html        html htm;
            }

            server {
              listen 8080;

              location / {
                root /mantis-faucet-web;
                index index.html;
                try_files $uri $uri/ /index.html;
              }

              {{ range service "${namespace}-mantis-faucet" -}}
              # https://github.com/input-output-hk/mantis-faucet-web/blob/nix-build/flake.nix#L14
              # TODO: the above FAUCET_NODE_URL should point to this
              location /rpc/node {
                proxy_pass  "http://{{ .Address }}:{{ .Port }}";
              }
              {{- end }}
            }
          }
        '';
        # TODO, make it signal when the above proxy_pass is used
        changeMode = "noop";
        changeSignal = "SIGHUP";
        destination = "local/nginx.conf";
      }];
    };

    tasks.telegraf = {
      driver = "docker";

      inherit vault;

      resources = {
        cpu = 100; # mhz
        memoryMB = 128;
      };

      config = {
        image = dockerImages.telegraf;
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
          urls = [ {{ with node "monitoring" }}"http://{{ .Node.Address }}:8428"{{ end }} ]
        '';

        destination = "local/telegraf.config";
      }];
    };
  };

  updateOneAtATime = {
    maxParallel = 1;
    # healthCheck = "checks"
    minHealthyTime = "30s";
    healthyDeadline = "10m";
    progressDeadline = "20m";
    autoRevert = false;
    autoPromote = false;
    canary = 0;
    stagger = "1m";
  };

  amountOfMiners = 5;

  miners = lib.forEach (lib.range 1 amountOfMiners) (num: {
    name = "mantis-${toString num}";
    requiredPeerCount = num - 1;
    publicServerPort = 9000 + num; # routed through haproxy/ingress
    publicDiscoveryPort = 9500 + num; # routed through haproxy/ingress
    publicRpcPort = 10000 + num; # routed through haproxy/ingress
  });

  minerJobs = lib.listToAttrs (lib.forEach miners (miner: {
    name = "${namespace}-${miner.name}";
    value = mkNomadJob miner.name {
      datacenters = [ "us-east-2" "eu-central-1" ];
      type = "service";
      inherit namespace;

      update = updateOneAtATime;

      taskGroups = lib.listToAttrs [ (mkMiner miner) ];
    };
  }));
in minerJobs // {
  "${namespace}-mantis-passive" = mkNomadJob "mantis-passive" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    update = updateOneAtATime;

    taskGroups = { passive = mkPassive 3; };
  };

  "${namespace}-morpho" = mkNomadJob "morpho" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    update = updateOneAtATime;

    taskGroups = let
      generateMorphoTaskGroup = nbNodes: node:
        lib.nameValuePair node.name (lib.recursiveUpdate (mkPassive 1)
          (mkMorpho (node // { inherit nbNodes; })));
      morphoTaskGroups =
        map (generateMorphoTaskGroup (builtins.length morphoNodes)) morphoNodes;
    in lib.listToAttrs morphoTaskGroups;
  };

  "${namespace}-explorer" = mkNomadJob "explorer" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    taskGroups.explorer = explorer;
  };

  "${namespace}-faucet" = mkNomadJob "faucet" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "service";
    inherit namespace;

    taskGroups.faucet = faucet;
  };

  "${namespace}-backup" = mkNomadJob "backup" {
    datacenters = [ "us-east-2" "eu-central-1" ];
    type = "batch";
    inherit namespace;

    periodic = {
      cron = "15 */1 * * * *";
      prohibitOverlap = true;
      timeZone = "UTC";
    };

    taskGroups.backup = import ./tasks/backup.nix {
      inherit lib dockerImages namespace mantis;
      name = "${namespace}-backup";
    };
  };
}
