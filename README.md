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
    * Linux (shouldn't be necessary on NixOS as it's supposed to be handled by activation):
    ```
    sudo systemctl restart nix-daemon.service
    ```
    * Darwin:
    ```
    sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist
    sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist
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
    $ nomad status testnet-mantis
    $ nomad alloc logs $ALLOC_ID > mantis-$ALLOC_ID.log
    $ nomad job stop mantis
    
    # etc.
    ```

* The nomad token is also used to authenticate to the mantis-ops Nomad web UI at: https://nomad.mantis.ws/
  * In the upper right hand corner of the Nomad web UI, click "ACL Tokens".
  * Enter the nomad token in "Secret ID" field and click "Set Token".
  * You will now have access to the full Nomad web UI.


### Consul Authentication

* Optionally, a Consul token can be exported in order to use Consul templates, described below:
    ```
    export CONSUL_HTTP_TOKEN="$(vault read -field token consul/creds/developer)"
    ```


### Mantis Ops Web UI Resources

* The following resources are available in the mantis-ops ecosystem, all behind oauth2 proxy authentication.
  * [Monitoring webpage](https://monitoring.mantis.ws)
    * Used to review and query metrics and logs for mantis processes and nodes.
  * [Nomad webpage](https://nomad.mantis.ws)
    * Used to review Nomad job status and related information.
    * Requires ACL token [authentication](https://nomad.mantis.ws/ui/settings/tokens) by providing the Nomad token generated in the steps above.
    * Provides UI capability to control Nomad job lifecycle (`Stop`, `Restart`) and interactive inspection (`Exec`) for specific allocations and/or jobs.
  * [Consul webpage](https://consul.mantis.ws)
    * Used to review mantis-ops cluster and service status.
  * [Vault webpage](https://vault.mantis.ws)
    * Used to review key-value paths utilized in ops configuration.
    * Requires a vault token for sign-in by providing the Vault token generated in the steps above.


### Metrics and Logs

* Metrics and logs can be found from the Grafana web UI at: https://monitoring.mantis.ws
* Querying logs by job identifier can be done through the "Explore" icon in the left vertical panel.
* If you don't see this "Explore" icon which looks like a compass, request "Editor" access from DevOps.
* Examples of log queries to the `Loki` log datasource in Grafana are:
    ```
    # In the "Log labels" field enter the following to search for all logs related to the `mantis-1` taskgroup:
    {syslog_identifier="mantis-1"}
    
    # In the "Log labels" field enter the following to search for all logs related to the `mantis-1` taskgroup
    # and filter for DAG events:
    {syslog_identifier="mantis-1"} |~ "DAG"
    ```


### Updating the Mantis source used for Deployments

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
* It is a good idea to commit mantis-source updates since a github action will automatically push the build product to cachix for faster job deployments for everyone on the team.


### Deployment: Running a Mantis Job

* Presently, there is no requirement to commit changes from a mantis job definition to the repository in order to deploy the job.
* To minimize confusion in the team about what job definition is running on the testnet, any changes to the mantis job made and deployed should be committed.
* To run a mantis job by deploying it to the testnet, execute the following command:
    ```
    $ nix run .#nomadJobs.mantis.run
    ```
* Versioning information about the deployment, including changes from the last version deployed, can be viewed in the Nomad UI in the [Versions](https://nomad.mantis.ws/ui/jobs/mantis/versions) section.


### The Mantis Job Definition File

* The mantis job definition is stored in file: `jobs/mantis.nix`
* Mantis miner and passive nodes are defined in this file, each with definitions of resource requirements, mantis configuration, lifecycle policy and quantity.
* This file can be edited to reflect the desired definition and then deployed with the command above.
* A job deployment can be done in a few ways:
  * In a single deployment where all taskgroups are deployed at once.
    * An example would be to deploy all bootstrap nodes and passive nodes at the same time so they all start at once.
  * In partial deployments where a subset of the full taskgroups in the job definition are deployed incrementally by changing the job definition slightly between each deployment, for example by editing passive node quantity or uncommenting pre-defined miners.
    * An example would be to deploy bootstrap miners first and then once they are running successfully to deploy passive nodes.
    * In the case of partial deployments, be aware that if the definition of taskgroups already deployed in an earlier step are modified, those particular taskgroup jobs will be restarted with the next deployment.
* Job definition information for the currently deployed job can be viewed in the Nomad UI in the [Definition](https://nomad.mantis.ws/ui/jobs/mantis/definition) section.


### Lifecycle Definitions: Healthchecks, Restarts and Reschedules

* In the mantis job definition file, a `checks` section and `checkRestart` sub-section define how to determine mantis job health.
  * Presently, mantis health is determined by an http call the `/healthcheck` endpoint.
  * See the [Check](https://www.nomadproject.io/api-docs/json-jobs#checks) and [CheckRestart](https://www.nomadproject.io/api-docs/json-jobs#checkrestart) reference urls for details.

* Job definitions of `restartPolicy` and `reschedulePolicy` are defined.
  * `restartPolicy` declares how an unhealthy mantis taskgroup should be restarted.  A restarted taskgroup will re-use its pre-existing state.
  * `reschedulePolicy` declares how an unhealthy mantis taskgroup which has failed to restart through its `restartPolicy` should be rescheduled.  A rescheduled taskgroup will be restarted from clean state.
  * See the [Restart Policy](https://www.nomadproject.io/api-docs/json-jobs#restart-policy) and [Reschedule Policy](https://www.nomadproject.io/api-docs/json-jobs#reschedule-policy) reference urls for details.


### Scaling For Performance Testing

* The job definition file can easily be used to scale the number of passive nodes by adjusting the number following the `mkPassive` function call.
* The job definition file can also be used to scale the number of bootstrap nodes by defining more miners in the `miners` list.
  * Pre-existing `enode-hash`, `key` and `coinbase` state needs to be created prior to deploying bootstrap nodes.
  * This state will be re-used across deployments and persists in the Vault `kv` store.
  * Additional bootstrap miner state only needs to be generated if the total number to be scaled to exceeds the number which currently exists (6 at the time of writing).
  * Pre-existing bootstrap node state can be viewed at the [testnet Vault kv](https://vault.mantis.ws/ui/vault/secrets/kv/list/nomad-cluster/testnet/) path.
  * This state pre-generation is done with the following command:
    ```
    nix run .#generate-mantis-keys $TOTAL_NUM_BOOTSTRAP_NODES
    ```


### Scaling Infrastructure Requirements

* If the mantis job definition is changed to require more Nomad client server infrastructure than is currently available, DevOps will deploy more infrastructure to host the additional Mantis taskgroups.


### Consul Templating

* Consul templates provide a powerful manner to extract real-time information about the mantis-ops cluster and services.
* Consul templates are described at their github repository [README.md](https://github.com/hashicorp/consul-template/blob/master/README.md) and utilize the [Go Template Format](https://golang.org/pkg/text/template/).


### Mapping Taskgoups to IPs

* For debugging purposes, it can be helpful to generate a real time map of running taskgroups and the associated public IP and node hostname (containing internal IP).
* To do this we can use a Consul template:
   ```
   $ consul-template -template templates/map.tmpl -once -dry -log-level err
   ```


### Starting a Mantis Local Node Connected to Testnet

* A local mantis node can be build and run connected to the testnet:
    ```
    # Build the mantis executables and configuration files
    $ nix build .#mantis -o mantis-node
    
    # Run a local mantis node against the testnet bootstrap cluster
    $ consul-template -template templates/mantis.tmpl:mantis-local.conf -exec './mantis-node/bin/mantis -Dconfig.file=./mantis-local.conf'
    ```
