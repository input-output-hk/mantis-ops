package tasks

#mantisBaseConfig: """
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
	  datadir = ${user.home}"/.mantis/"${mantis.blockchains.network}

	  # The unencrypted private key of this node
	  node-key-file = ${mantis.datadir}"/node.key"

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
	    keystore-dir = ${mantis.datadir}"/keystore"

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
	        socket-file = ${mantis.datadir}"/mantis.ipc"
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

	    ethash-dir = ${user.home}"/.ethash"

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
	      custom-genesis-file = "/local/genesis.json"

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
	      path = ${mantis.datadir}"/rocksdb/"

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
	  logs-dir = ${mantis.datadir}"/logs"

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
	"""
