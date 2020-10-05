#  Mantis Ops


## Introduction

* Mantis ops utilizes the [bitte](https://github.com/input-output-hk/bitte) tool stack to implement a cluster of Mantis nodes.
* See the [bitte](https://github.com/input-output-hk/bitte) and [bitte-cli](https://github.com/input-output-hk/bitte-cli) repos for information on the underlying stack technology which includes: Vault, Consul, Nomad, Grafana, Telegraf, VictoriaMetrics, Loki and more.


## Getting Started for Developers

### Nix

* Nix is a requirement for this project.
* If you don't already have Nix installed, please install it by following the directions at: [Nix Installation](https://nixos.org/manual/nix/stable/#chap-installation).
* Either a single-user nix install or a multi-user nix install is supported.
nix-env -iA cachix -f https://cachix.org/api/v1/install
cachix use mantis-ops


### Nix Shell

* Once Nix is installed, clone this mantis-ops repo to your local machine and enter the local repository directory:
```
git clone git@github.com:input-output-hk/mantis-ops
cd mantis-ops
```

* Enter into a nix-shell with all required dependencies, including Nix flakes support and binary caches to improve initial set up time:
```
NIX_USER_CONF_FILES=./nix.conf nix-shell --run '
( nix build .#nixFlakes -o devShell
  nix-env -i ./devShell
  rm devShell
) || nix profile install github:input-output-hk/mantis-ops#nixFlakes
'

nix develop
```


### Github Access Token

* To authenticate to the mantis-ops project, use your github ID to create a personal access token for mantis-ops if you don't already have one:
  * Login into github.com with your github work user id.
  * Navigate to the [Personal Access Tokens](https://github.com/settings/tokens) page of github.
  * Click "Generate new token".
  * Type "mantis-ops" in the "Note" field.
  * Under the "Select scopes" section, check mark the "read:org" field ONLY (described as "Read org and team membership, read org projects") under the "admin:org" area.
  * Click "Generate token".
  * Copy the new personal access token you are presented with as you will use it in a subsequent step and it is only shown once on the github webpage.
  * At any time, you can delete an existing mantis-ops github token and create a new one to provide in the steps below.


### Vault Authentication

* From your nix-shell, obtain a vault token by supplying the following command with your github mantis-ops personal access token when prompted:
```
$ vault login -method github -path github-employees
```

* After logging into vault, if you need to see your vault token again or review information associated with your token, you can view it with the following command:
```
$ vault token lookup
```

* To see only your vault token, without additional information, use the following command:
```
$ vault print token
```


### Nomad Authentication

* After logging into vault, you can obtain a nomad token for the developer role with the following command:
```
$ vault read -field secret_id nomad/creds/developer
```

* Optionally, you can export this token locally to have access to the nomad cli which will enable additional cli debugging capabilities.  For example:
```
# Export the nomad developer token to NOMAD_TOKEN:
$ export NOMAD_TOKEN="$(vault read -field secret_id nomad/creds/developer)"

# Now the nomad cli becomes available.
# The following are some examples commands that may be useful:
$ nomad status
$ nomad status mantis
$ nomad alloc logs $ALLOC_ID > mantis-$ALLOC_ID.log
$ nomad job stop mantis

# etc.
```

* The nomad token is also used to authenticate to the mantis-ops Nomad web UI at: https://nomad.mantis.ws/
  * In the upper right hand corner of the Nomad web UI, click "ACL Tokens".
  * Enter the nomad token in "Secret ID" field and click "Set Token".
  * You will now have access to the full Nomad web UI.


### Running a Mantis Job

* Near the top of the `./overlay.nix` file of the mantis-ops repository, the mantis commit ref is seen, where $COMMIT represent the actual commit revision and $BRANCH represents the branch of the commit, typically `develop`:
```
  mantis-source = builtins.fetchGit {
    url = "https://github.com/input-output-hk/mantis";
    rev = "$COMMIT";
    ref = "$BRANCH";
    submodules = true;
  };

```
* To update the commit that a mantis job will be run up, update the `rev` and `ref` fields with the appropriate git commit revision and git commit branch.
* To run a mantis job, execute the following command:
```
$ nix run .#nomadJobs.mantis.run
```


### Metrics and Logs

* Metrics and logs can be found from the Grafana web UI at: https://monitoring.mantis.ws
* A user ID and password will be provided.
* Oauth or another authentication method will be added in the near future.
