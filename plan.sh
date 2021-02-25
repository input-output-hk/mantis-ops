#!/usr/bin/env bash

set -euo pipefail

status () {
  if [ "ok" = "$1" ]; then
    printf "\r[✓] %-30s" "$2"
  elif [ "finished" = "$1" ]; then
    printf "\r[✓] %-30s\n\n" "$2"
  else
    printf "\r[⏳] %-30s" "$2"
  fi
}

NOMAD_NAMESPACE="${NOMAD_NAMESPACE:-}"

if [ -z "$NOMAD_NAMESPACE" ]; then
  echo "Please set the NOMAD_NAMESPACE environment variable first"
  exit 1
fi

export NOMAD_NAMESPACE
status ok NOMAD_NAMESPACE

################################################################################

status pending VAULT_TOKEN
VAULT_TOKEN="${VAULT_TOKEN:-}"

if ! vault token lookup &> /dev/null; then
  VAULT_TOKEN="$(vault login -method github -path github-employees -token-only)"
else
  VAULT_TOKEN="$(vault print token)"
fi

export VAULT_TOKEN
status ok VAULT_TOKEN

################################################################################

NOMAD_TOKEN="${NOMAD_TOKEN:-}"
status pending NOMAD_TOKEN

if [ -z "$NOMAD_TOKEN" ] \
  || ! nomad acl token self | grep -v  'Secret ID' &> /dev/null; then
  NOMAD_TOKEN="$(vault read -field secret_id nomad/creds/developer)"
fi

export NOMAD_TOKEN
status ok NOMAD_TOKEN

################################################################################

CONSUL_HTTP_TOKEN="${CONSUL_HTTP_TOKEN:-}"
status pending CONSUL_HTTP_TOKEN

if [ -z "$CONSUL_HTTP_TOKEN" ] \
  || ! consul acl token read -self -format json \
  | jq -e '.Policies | map(.Name) | inside(["admin", "github-employees"])' \
  &>/dev/null; then
  CONSUL_HTTP_TOKEN="$(vault read -field token consul/creds/developer)"
fi

export CONSUL_HTTP_TOKEN
status ok CONSUL_HTTP_TOKEN

################################################################################

status finished "all tokens present"

GET () {
  response="$(curl -s -q "$NOMAD_ADDR/v1/$1" -H "X-Nomad-Token: $NOMAD_TOKEN")"
  echo "$response" | jq -e 2>/dev/null || (echo "$response" >/dev/stderr; exit 1)
}

POST () {
  response="$(
  echo "$2" \
    | curl -s -q -d @- "$NOMAD_ADDR/v1/$1" \
    -H "X-Nomad-Token: $NOMAD_TOKEN" \
    -H "X-Vault-Token: $VAULT_TOKEN"
  )"
  echo "$response" | jq -e 2>/dev/null || (echo "$response" >/dev/stderr; exit 1)
}

cli_plan () {
  namespace="$1"
  job="$2"

  json="$(
  cue export --out json \
    | jq --arg namespace "$namespace" --arg job "$job" -e '.rendered[$namespace][$job]' \
    | jq --arg token "$CONSUL_HTTP_TOKEN" '.Job.ConsulToken = $token' \
    | jq '.Diff = true'
  )"

  ID="$(echo "$json" | jq -e -r .Job.ID)"

  plan="$(POST "job/$ID/plan" "$json")"
  echo "$plan"
  JobModifyIndex="$(echo "$plan" | jq -e .JobModifyIndex)"
  echo "JobModifyIndex: $JobModifyIndex"

  # returns:
  # {
  #   "Annotations": {
  #     "DesiredTGUpdates": {
  #       "mantis": {
  #         "Canary": 1,
  #         "DestructiveUpdate": 0,
  #         "Ignore": 3,
  #         "InPlaceUpdate": 0,
  #         "Migrate": 0,
  #         "Place": 0,
  #         "Preemptions": 0,
  #         "Stop": 0
  #       }
  #     },
  #     "PreemptedAllocs": null
  #   },
  #   "CreatedEvals": null,
  #   "Diff": null,
  #   "FailedTGAllocs": null,
  #   "Index": 2490602,
  #   "JobModifyIndex": 2490602,
  #   "NextPeriodicLaunch": null,
  #   "Warnings": ""
  # }

  RUN=""
  until [ -n "$RUN" ]; do
    read -r -p "run this job? (yes/no): " RUN
    if [ "$RUN" = "yes" ]; then
      cli_run "$namespace" "$job" "$JobModifyIndex"
      exit 0
    fi
  done
}

cli_run () {
  namespace="$1"
  job="$2"
  index="$3"

  json="$(
  cue export --out json \
    | jq --arg namespace "$namespace" --arg job "$job" -e '.rendered[$namespace][$job]' \
    | jq --arg token "$CONSUL_HTTP_TOKEN" '.Job.ConsulToken = $token' \
    | jq --argjson index "$index" '.JobModifyIndex = $index' \
    | jq '.EnforceIndex = true'
  )"

  result="$(POST "jobs" "$json")"
  echo "job: $result"

  # returns:
  # {
  #   "EvalCreateIndex": 2491067,
  #   "EvalID": "dde99990-35b7-5d8b-cffd-eee2999922e5",
  #   "Index": 2491067,
  #   "JobModifyIndex": 2491067,
  #   "KnownLeader": false,
  #   "LastContact": 0,
  #   "Warnings": ""
  # }

  EvalID="$(echo "$result" | jq -r -e .EvalID)"
  echo "EvalID: $EvalID"

  evaluation="$(GET "evaluation/$EvalID")"
  echo "evaluation: $evaluation"

  until [ "$(echo "$evaluation" | jq -r -e .Status)" != "pending" ]; do
    sleep 1
    evaluation="$(GET "evaluation/$EvalID")"
    echo "evaluation: $evaluation"
  done

  # returns
  # {
  #   "CreateIndex": 2491067,
  #   "CreateTime": 1614174177265950000,
  #   "DeploymentID": "d62f3d1e-fc91-d221-cb90-f02f207df969",
  #   "ID": "dde99990-35b7-5d8b-cffd-eee2999922e5",
  #   "JobID": "miner",
  #   "JobModifyIndex": 2491067,
  #   "ModifyIndex": 2491069,
  #   "ModifyTime": 1614174177405316900,
  #   "Namespace": "mantis-unstable",
  #   "Priority": 50,
  #   "QueuedAllocations": {
  #     "mantis": 0
  #   },
  #   "SnapshotIndex": 2491067,
  #   "Status": "complete",
  #   "TriggeredBy": "job-register",
  #   "Type": "service"
  # }

  DeploymentID="$(echo "$evaluation" | jq -r -e .DeploymentID)"
  echo "DeploymentID: $DeploymentID"

  # deployment="$(GET "deployment/$DeploymentID")"
  # returns
  # {
  #   "CreateIndex": 2491068,
  #   "ID": "d62f3d1e-fc91-d221-cb90-f02f207df969",
  #   "IsMultiregion": false,
  #   "JobCreateIndex": 2489899,
  #   "JobID": "miner",
  #   "JobModifyIndex": 2491067,
  #   "JobSpecModifyIndex": 2491067,
  #   "JobVersion": 4,
  #   "ModifyIndex": 2491092,
  #   "Namespace": "mantis-unstable",
  #   "Status": "running",
  #   "StatusDescription": "Deployment is running",
  #   "TaskGroups": {
  #     "mantis": {
  #       "AutoPromote": true,
  #       "AutoRevert": true,
  #       "DesiredCanaries": 1,
  #       "DesiredTotal": 3,
  #       "HealthyAllocs": 1,
  #       "PlacedAllocs": 2,
  #       "PlacedCanaries": [
  #         "8ab5920b-7eb7-4d02-7025-f76d6e83b478"
  #       ],
  #       "ProgressDeadline": 900000000000,
  #       "Promoted": true,
  #       "RequireProgressBy": "2021-02-24T14:03:01.268243077Z",
  #       "UnhealthyAllocs": 0
  #     }
  #   }
  # }

  # GET "deployment/$DeploymentID"

  watch -g -d "curl -s -H \"X-Nomad-Token: $NOMAD_TOKEN\" \"$NOMAD_ADDR/v1/deployment/$DeploymentID\" | jq ."
}

cmd="${1:-}"
namespace="${2:-}"
job="${3:-}"

case "$cmd" in plan)
  cli_plan "$namespace" "$job"
;; run)
  cli_run "$namespace" "$job" "${4:-0}"
;; *)
  echo "unknown command: '$cmd', must be one of plan | run"
esac
