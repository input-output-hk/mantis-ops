package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"list"
	"math"
	encjson "encoding/json"
)

#Morpho: types.#stanza.task & {
	#namespace:        string
	#nbNodes:          5
	#requiredMajority: math.Floor((#nbNodes / 2) + 1)
	#morphoRev:        types.#gitRevision

	driver: "exec"

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	resources: {
		cpu:    100
		memory: 1024
	}

	config: {
		flake:   "github:input-output-hk/ECIP-Checkpointing?rev=\(#morphoRev)#morpho"
		command: "/bin/morpho-checkpoint-node"
		args: [
			"--topology", "/local/morpho-topology.json",
			"--database-path", "/local/db",
			"--port", "${NOMAD_PORT_morpho}",
			"--config", "/local/morpho-config.yaml",
			"--socket-dir", "/local/socket",
		]
	}

	restart_policy: {
		interval: "10m"
		attempts: 10
		delay:    "30s"
		mode:     "delay"
	}

	template: "local/morpho-topology.json": {
		let range = list.Range(0, #nbNodes, 1)
		let addressFor = {
			#n:      uint
			addr:    "_\(#namespace)-morpho-node._obft-node-\(#n).service.consul."
			valency: 1
		}
		let map = [ for n in range {
			nodeId: n
			producers: [ for p in range if p != n {addressFor & {#n: p}}]
		}]
		data: encjson.Marshal(map)
	}

	template: "secrets/morpho-private-key": {
		data:        """
			{{- with secret (printf "kv/data/nomad-cluster/\(#namespace)/obft-node-%s/obft-secret-key" (env "NOMAD_ALLOC_INDEX")) -}}
			{{- .Data.data.value -}}
			{{- end -}}
			"""
		change_mode: "noop"
		splay:       "15m"
	}

	template: "local/morpho-config.yaml": {
		change_mode: "noop"
		splay:       "15m"
		data:        """
    ApplicationName: morpho-checkpoint
    ApplicationVersion: 1
    CheckpointInterval: 4
    FedPubKeys: [
    {{ range secrets "kv/metadata/nomad-cluster/\(#namespace)/" -}}
      {{- if . | contains "obft" -}}
          "{{- with secret (printf "kv/data/nomad-cluster/\(#namespace)/%s/obft-public-key" . ) -}}{{ .Data.data.value }}{{end}}",
      {{ end }}
    {{- end -}}
    ]
    LastKnownBlockVersion-Major: 0
    LastKnownBlockVersion-Minor: 2
    LastKnownBlockVersion-Alt: 0
    NetworkMagic: 12345
    NodeId: {{ env "NOMAD_ALLOC_INDEX" }}
    NodePrivKeyFile: {{ env "NOMAD_SECRETS_DIR" }}/morpho-private-key
    NumCoreNodes: \(#nbNodes)
    PoWBlockFetchInterval: 5000000
    PoWNodeRpcUrl: http://127.0.0.1:{{ env "NOMAD_PORT_rpc" }}
    PrometheusPort: {{ env "NOMAD_PORT_morphoPrometheus" }}
    Protocol: MockedBFT
    RequiredMajority: \(#requiredMajority)
    RequiresNetworkMagic: RequiresMagic
    SecurityParam: 2200
    StableLedgerDepth: 6
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
    """
	}
}
