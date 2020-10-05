#  Mantis Ops


## Introduction

* Mantis ops utilizes the [bitte](https://github.com/input-output-hk/bitte) tool stack to implement a cluster of Mantis nodes.
* See the [bitte](https://github.com/input-output-hk/bitte) and [bitte-cli](https://github.com/input-output-hk/bitte-cli) repos for information on the underlying stack technology which includes: Vault, Consul, Nomad, Grafana, Telegraf, VictoriaMetrics, Loki and more.


## Getting Started for Developers

### Nix Installation

* Nix is a requirement for this project.
* If you don't already have Nix installed, please install it by following the directions at [Nix Installation](https://nixos.org/manual/nix/stable/#chap-installation).
* A multi-user Nix installation is recommended over a single-user Nix installation as the multi-user install has advantages, such as being able to handle multiple builds in parallel.
  * To install Nix as a single-user install, the following command can be run as a regular non-root user with `sudo` access:
```
$ sh <(curl -L https://nixos.org/nix/install) --no-daemon
```
  * To install Nix as a multi-user install, the following command can be run as a regular non-root user with `sudo` access:
```
$ sh <(curl -L https://nixos.org/nix/install) --daemon
```
* After performing a Nix single or multi-user install, any shells should be exited and re-entered to ensure the new Nix settings take effect in the environment.
* Alternatively, the operating system [NixOS](https://nixos.org/manual/nixos/stable/#sec-installation) can be used which includes a Nix installation.


### Nix Configuration

* After Nix is installed, Nix needs to have a few things customized to utilize new features and a project specific cache.
* For a Nix single-user install, the Nix configuration file will be found at the following location.  Create this diretory structure and file if it does not yet exist:
```
$ mkdir -p ~/.config/nix
$ touch ~/.config/nix/nix.conf
```

* For a Nix multi-user install, the Nix configuration file will be found at the following location:
```
$ ls -la /etc/nix/nix.conf
```

* The following configuration lines need to be added to the Nix configuration:
```
experimental-features = nix-command flakes ca-references
substituters = https://cache.nixos.org https://mantis-ops.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= mantis-ops.cachix.org-1:SornDcX8/9rFrpTjU+mAAb26sF8mUpnxgXNjmKGcglQ=
```

* Additionally, for a Nix multi-user install:
  * The following line should also be added, where `<YOUR_USERNAME>` is substituted with your actual non-root username:
```
trusted-users = <YOUR_USERNAME>
```
  * Once the new configuration lines have been added, the nix-daemon service needs to be restarted for the full Nix configuration changes to take effect:
```
sudo systemctl restart nix-daemon.service
```

* If lines for `experimental-features`, `substituters`, `trusted-public-keys` or `trusted-users` already exist in your Nix configuration file, then merge the lines above with the content that is already pre-existing in your Nix configuration.
* For a NixOS installation, the following declarative code snippet in the machine NixOS configuration file, usually found at `/etc/nixos/configuration.nix`, followed by a `sudo nixos-rebuild switch` will add and activate the modified Nix configuration:
```
  nix.binaryCaches = [
    "https://cache.nixos.org/"
    "https://mantis-ops.cachix.org"
  ];
  nix.binaryCachePublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "mantis-ops.cachix.org-1:SornDcX8/9rFrpTjU+mAAb26sF8mUpnxgXNjmKGcglQ="
  ];
  nix.extraOptions = ''
    experimental-features = nix-command flakes ca-references
  '';

```


### Nix Shell

* Once Nix is installed and configured, clone the mantis-ops repo to your local machine and enter the local repository directory:
```
# For cloning using a github registered key:
$ git clone git@github.com:input-output-hk/mantis-ops

# or, for cloning without a github registered key:
$ git clone https://github.com/input-output-hk/mantis-ops

$ cd mantis-ops
```

* After entering the repository directory, the following command needs to be run ONLY ONCE.  This will set up all the required dependencies for the nix-shell environment, including Nix flakes support and install them into the nix user profile:
```
nix-shell --run '
( nix build .#nixFlakes -o devShell
  nix-env -i ./devShell
  rm devShell
) || nix profile install github:input-output-hk/mantis-ops#nixFlakes
'
```

* Finally, enter the development environment with the following command.  This command should be executed whenever you have a new shell and you'd like to enter the development enviroment:
```
nix develop
```


### Github Access Token

* To authenticate to the mantis-ops project, use your github ID to create a personal access token for mantis-ops if you don't already have one:
  * Login into github.com with your github work user id.
  * Navigate to the [Personal Access Tokens](https://github.com/settings/tokens) page of github.
  * Click "Generate new token".
  * Type "mantis-ops" in the "Note" field.
  * Under the "Select scopes" section, check mark ONLY the "read:org" field described as "Read org and team membership, read org projects" under the "admin:org" area.
  * Click "Generate token".
  * Copy the new personal access token you are presented with as you will use it in a subsequent step and it is only shown once on the github webpage.
  * At any time, you can delete an existing mantis-ops github token and create a new one to provide in the steps below.


### Vault Authentication

* From your nix development environment, obtain a vault token by supplying the following command with your github mantis-ops personal access token when prompted:
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
# Export the nomad developer token:
$ export NOMAD_TOKEN="$(vault read -field secret_id nomad/creds/developer)"

# Now the nomad cli becomes available.
# The following are some example commands that may be useful:
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

* Near the top of the `./overlay.nix` file of the mantis-ops repository, the mantis commit ref is seen, where $COMMIT represents the actual commit revision and $BRANCH represents the branch of the commit, typically `develop`:
```
  mantis-source = builtins.fetchGit {
    url = "https://github.com/input-output-hk/mantis";
    rev = "$COMMIT";
    ref = "$BRANCH";
    submodules = true;
  };

```
* To update the commit that a mantis job will be run with, update the `rev` and `ref` fields with the appropriate git commit revision and git commit branch.
* To run a mantis job, execute the following command:
```
$ nix run .#nomadJobs.mantis.run
```


### Metrics and Logs

* Metrics and logs can be found from the Grafana web UI at: https://monitoring.mantis.ws
* A user ID and password will be provided.
* Oauth or another authentication method will be added in the near future.
