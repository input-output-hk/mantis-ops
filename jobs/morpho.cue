package jobs

import "github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"

#Morpho: types.#stanza.job & {
	namespace:  string
	#namespace: namespace // referenced later
	type:       "service"
	#name:      "\(namespace)-faucet"
	#domain:    string
	#wallet:    string | *"mantis-1"
	#dockerImages: [string]: {
		name: string
		tag:  string
		url:  string
	}

	update: {
		max_parallel:      1
		health_check:      "checks"
		min_healthy_time:  "30s"
		healthy_deadline:  "10m"
		progress_deadline: "20m"
		auto_revert:       false
		auto_promote:      false
		canary:            0
		stagger:           "1m"
	}
}
