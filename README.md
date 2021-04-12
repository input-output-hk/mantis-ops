#  Mantis Ops


## Introduction

* Mantis ops utilizes the [bitte](https://github.com/input-output-hk/bitte) tool stack to implement a cluster of Mantis nodes.
* See the [bitte](https://github.com/input-output-hk/bitte) and [bitte-cli](https://github.com/input-output-hk/bitte-cli) repos for information on the underlying stack technology which includes: Vault, Consul, Nomad, Grafana, Telegraf, VictoriaMetrics, Loki and more.


## Getting Started for Developers

### Running Nix in Docker

For simple tasks such as deployment it might be sufficient to use a Nix environment via Docker. (This is especially convenient for Mac users due to Darwin-compatibility issues of some of the dependencies.) You can use the `nix-in-docker/run` script to run `nix-shell`:

```
$ nix-in-docker/run
```

Extra arguments are passed to `nix-shell`, eg. to access the repl directly:
```
$ nix-in-docker/run --run 'nix repl repl.nix'
```

The `/root` and `/nix` volumes are persisted between runs, so you only need to do [Vault Authentication](#vault-authentication) once. After that you should be able to deploy eg. staging Mantis by running the following:

```
$ nix-in-docker/run
...
[nix-shell:/mantis-ops]# iogo plan mantis-staging miner

```

#### Trouble shooting running Nix in Docker

* If you see something like this when running the build
```
Error ------------------------------------------------------------------------------------------------------------------------------------------------------ nix
builder for '/nix/store/kszgacdv6gfdsk0hm4xg3bmx86b7zv34-mantis-3.2.1.drv' failed with exit code 137
error: --- Error ------------------------------------------------------------------------------------------------------------------------------------------------------ nix
1 dependencies of derivation '/nix/store/3dw8fzklhhl7bnsamw9mnhanfgmbcryb-docker.mantis.ws-mantis-bulk-layers.drv' failed to build
```
that means you use automatically allocated memory in Docker and it's not enough. Go to Docker -> Resources -> Memory, setting it to 4Gb should be enough.

* If you encounter this error when running the deploy command
```
FATA[0000] Error initializing source docker-archive:///nix/store/hmnzy4n45fmn1p9caq47pz652f6d6q1m-docker.mantis.ws-mantis.tar.gz: error creating temporary file: open /var/tmp/docker-tar540472188: no such file or directory
```
it means you have to create mentioned folders manually with this command:
```
mkdir -p /var/tmp
```
### Nix Installation

* Nix is a requirement for this project.
* If you don't already have Nix installed, please install it by following the directions at [Nix Installation](https://nixos.org/manual/nix/stable/#chap-installation).
* A multi-user Nix installation is recommended over a single-user Nix installation as the multi-user install has advantages, such as being able to handle multiple builds in parallel.
* A multi-user Nix installation also avoids some edge case build issues that may be encountered with a single-user Nix installation.
* In general, unless you have difficulty installing multi-user Nix, or have a specific reason to use a single-user Nix installation, proceed with a multi-user Nix installation.
  * *RECOMMENDED:* To install Nix as a multi-user install, the following command can be run as a regular non-root user with `sudo` access:
    ```
    $ sh <(curl -L https://nixos.org/nix/install) --daemon
    ```
  * *NOT RECOMMENDED:* To install Nix as a single-user install, the following command can be run as a regular non-root user with `sudo` access:
    ```
    $ sh <(curl -L https://nixos.org/nix/install) --no-daemon
    ```
* After performing a Nix multi-user or single-user install, any shells should be exited and re-entered to ensure the new Nix settings take effect in the environment.
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
    substituters = https://hydra.iohk.io https://cache.nixos.org https://hydra.mantis.ist
    trusted-public-keys = hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= hydra.mantis.ist-1:4LTe7Q+5pm8+HawKxvmn2Hx0E3NbkYjtf1oWv+eAmTo=
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
        "https://hydra.iohk.io"
        "https://cache.nixos.org"
        "https://hydra.mantis.ist"
      ];
      nix.binaryCachePublicKeys = [
        "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "hydra.mantis.ist-1:4LTe7Q+5pm8+HawKxvmn2Hx0E3NbkYjtf1oWv+eAmTo="
      ];
      nix.extraOptions = ''
        experimental-features = nix-command flakes ca-references
      '';
      nix.package = pkgs.nixUnstable;
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
  NB. This should not be done for Nix in Docker.

* Finally, enter the development environment with the following command.  This command should be executed whenever you have a new shell and you'd like to enter the development enviroment:
    ```
    nix develop
    ```

* Users who use `direnv` can skip running the `nix develop` command each time a new development environment is needed by running `direnv allow` once from within the `mantis-ops` directory.
  * Direnv will then automatically enter the nix development environment each time the `mantis-ops` directory is entered.


### Github Access Token

* Github users who are in the IOHK team `mantis-devs` have the ability to authenticate to the mantis-ops project as developers.
  * If you are not in the `mantis-devs` github team and require access to the mantis-ops project, request team membership from the Mantis project team.

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


### Mantis-Ops Namespaces

* The mantis-ops deployed infrastructure is separated into namespaces where jobs can either run in the main testnet namespace, `mantis-testnet` or a different namespace.
* In general, use of the appropriate namespace as a parameter will be required when interacting with the mantis-ops projects.
* Examples of this are:
  * From the Monitoring webpage, some dashboards may include a Nomad namespace parameter near the top of the dashboard; also some queries may be parameterized with namespace
  * From the Nomad webpage, a namespace drop-down selector will be visible in the top left of the UI
  * From the Nomad CLI, a `-namespace $NAMESPACE` parameter is often required to return appropriate results
  * From the Consul webpage, Consul CLI and consul-template results, registered services will generally have the Nomad namespace embedded in the service name
  * From the Vault webpage and Vault CLI, in the kv/nomad-cluster path, subpaths will be prefixed by Nomad namespace


### Metrics and Logs

* Metrics and logs can be found from the Grafana web UI at: https://monitoring.mantis.ws
* Querying logs by job identifier can be done through the "Explore" icon in the left vertical panel.
* If you don't see this "Explore" icon which looks like a compass, request "Editor" access from DevOps.
* Examples of log queries to the `Loki` log datasource in Grafana are:
    ```
    # In the "Log labels" field enter the following to search for all logs related to the `mantis-testnet` namespace:
    {namespace="mantis-testnet"}

    # In the "Log labels" field enter the following to search for all logs related to the `mantis-testnet` namespace
    # and filter for DAG events:
    {namespace="mantis-testnet"} |~ "DAG"
    ```
    A full reference of LogQL is [available](https://grafana.com/docs/loki/latest/logql) as well.

* Logs can also be obtained from the command line with commands such as:
   ```
   # Generalized example:
   nomad status -namespace $NS $JOB | grep "$TG.*running" | head -1 | awk '{ print $1 }' | xargs -Ix nomad logs -namespace "$NS" [-stderr] [-tail] [-f] [-n LINES] [-verbose] x "$TG"

   # Tail and follow a miner job taskgroup (mantis) in namespace mantis-testnet:
   TG="mantis"; NS="mantis-testnet"; JOB="miner"; nomad status -namespace "$NS" "$JOB" \
     | grep "$TG.*running" | head -1 | awk '{ print $1 }' \
     | xargs -Ix nomad logs -namespace "$NS" -tail -f x "$TG"

   # Output from commands above can be redirected to a local file by appending `> $LOG_OUTPUT_FILENAME` for further grep inspection
   ```


### Updating the Mantis source used for Deployments

* You can change the revision of Mantis that Nomad jobs are deployed with from
  [`deploy.cue`](https://github.com/input-output-hk/mantis-ops/blob/7fdb3d5945a59c29cd0f03654fde20d5ed84b1cb/deploy.cue#L28).
  * It's a good idea to keep the revision specified here and in `flake.nix`'s `inputs.mantis` in sync so that Hydra will build the proper revision for faster deployments.

#### Updating Package Sources

* Near the top of the `./overlay.nix` file of the mantis-ops repository, the mantis commit ref is seen, where $COMMIT represents the actual commit revision and $BRANCH represents the branch of the commit, typically `develop`:
    ```
      mantis-staging-source = builtins.fetchGit {
        url = "https://github.com/input-output-hk/mantis";
        rev = "$COMMIT";
        ref = "$BRANCH";
        submodules = true;
      };

    ```
* To update the commit that a package will build with, update the `rev` and `ref` fields with the appropriate git commit revision and git commit branch.
* It is a good idea to commit any source updates since Hydra will automatically push the build product to a cache for faster job deployments for everyone on the team.
* Other repo sources which are found in `flake.nix` and may need an update, such as `mantis-faucet-web`, can be updated from the nix develop shell and then committed as needed:
    ```
      # Update a selected flake repo input (example: mantis-faucet-web)
      $ nix flake update --update-input mantis-faucet-web
    ```

### Deployment: Running a Mantis Job

* Presently, there is no requirement to commit changes from a mantis job definition to the repository in order to deploy the job.
* To minimize confusion in the team about what job definition is running on the testnet, any changes to the mantis job made and deployed should be committed.

* To run a mantis-ops job by deploying it to the testnet, execute the following command:
    ```
    # Deployments are handled with the `iogo` tool from the `bitte` package
    $ iogo plan $namespace $job
    #
    # Example for building and running only the mantis-testnet explorer job:
    $ iogo plan mantis-testnet explorer
    ```
    To help avoid unwanted changes, a confirmation dialogue will list a diff of
    the planned changes before deployment actually runs.

* Versioning information about the deployment, including changes from the last
  version deployed, can be viewed in the Nomad UI in the
  "Versions" section for a given namespace, e.g. the [mantis-testnet
versions](https://nomad.mantis.ws/ui/jobs/miner/versions?namespace=mantis-testnet).

### Debugging Mantis Nodes

It is possible to set the logging level for individual classes in order to assist in debugging without flooding the logs with irrelevant detail.

To get started, open up the `deploy.cue` file, and look for the `#loggers` set under `vars`.

The default values are given for the sake of example. You can either add your own classes: `"CLASSNAME": "LOGLEVEL"`, or modify the existing values to the desired level. The special value `"${LOGLEVEL}"` refers to the global `logging.logs-level` setting.

#### Global logging

If you wish set the global logging level for all namespaces, simply open the `deploy.cue` file and change `#logLevel`, where the `*` designates the default value if unset elsewhere.

If you only want it on for a particular Nomad namespace, you can set `#logLevel` to the appropriate value under a given namespace's `vars` in `deploy.cue`:
```cue
#namespaces: {
  // ...
  "mantis-staging": {
      vars: {
        #logLevel: "DEBUG"
        // other vars ...
      }
      // ...
  }
}
```

### Nix Repl For Exploring Nix Attributes

* Nix repl can be used for finding nix attributes by entering a nix repl environment:
    ```
    $ nix repl repl.nix
    ```
* Nomad server conigs are available via `nixosConfigurations`.
* Packages are available via `legacyPackages` and `hydraJobs`.
* Tab completion works in the repl to help explore an attribute set:
  ```console
  nix-repl> hydraJobs.x86_64-linux.<tab>
  hydraJobs.x86_64-linux.bitte
  hydraJobs.x86_64-linux.cfssl
  hydraJobs.x86_64-linux.consul
  hydraJobs.x86_64-linux.cue
  hydraJobs.x86_64-linux.devShellPath
  hydraJobs.x86_64-linux.generate-mantis-keys
  ...
  ```

### Finding Nomad Jobs

* Jobs are defined in the toplevel `deploy.cue` for each namespace.

### Mantis-Ops Job Definition Files

* If you're not already familiar, be sure to check out the official [Cue Documentation](https://cuelang.org/docs).

* The mantis job definition for the `mantis-testnet` namespace is stored in file: `jobs/mantis.cue`
* Mantis miner and passive nodes are defined in this file, each with definitions of resource requirements (set in the imported tasks file), mantis configuration, lifecycle policy and quantity.
* This file can be edited to reflect the desired definition and then deployed with the command above.
* A job deployment can be done in a few ways:
  * In a single deployment where all taskgroups are deployed at once.
    * An example would be to deploy all bootstrap nodes and passive nodes at the same time so they all start at once.
  * In partial deployments where a subset of the full taskgroups in the job definition are deployed incrementally by changing the job definition slightly between each deployment, for example by editing passive node quantity or uncommenting pre-defined miners.
    * An example would be to deploy bootstrap miners first and then once they are running successfully to deploy passive nodes.
    * In the case of partial deployments, be aware that if the definition of taskgroups already deployed in an earlier step are modified, those particular taskgroup jobs will be restarted with the next deployment.
* Job definition information for a currently deployed job can be viewed in the Nomad UI in the
[Definition](https://nomad.mantis.ws/ui/jobs/miner/definition?namespace=mantis-testnet) section under the appropriate namespace.
* Each task group has it's own cue file under the `jobs/tasks` directory which gets imported by the `job/*.cue` files.
* If you run into any cue type errors, you can review type defintions in `schemas/nomad/types.cue` to ensure you haven't misused a type.

### Lifecycle Definitions: Healthchecks, Restarts and Reschedules

* In the mantis-ops job definition files, a `checks` section and `checkRestart` sub-section define how to determine mantis job health.
  * Presently, mantis health is determined by an http call the `/healthcheck` endpoint.
  * See the [Check](https://www.nomadproject.io/api-docs/json-jobs#checks) and [CheckRestart](https://www.nomadproject.io/api-docs/json-jobs#checkrestart) reference urls for details.

* Job definitions of `restartPolicy` and `reschedulePolicy` are defined.
  * `restartPolicy` declares how an unhealthy mantis taskgroup should be restarted.  A restarted taskgroup will re-use its pre-existing state.
  * `reschedulePolicy` declares how an unhealthy mantis taskgroup which has failed to restart through its `restartPolicy` should be rescheduled.  A rescheduled taskgroup will be restarted from clean state.
  * See the [Restart Policy](https://www.nomadproject.io/api-docs/json-jobs#restart-policy) and [Reschedule Policy](https://www.nomadproject.io/api-docs/json-jobs#reschedule-policy) reference urls for details.


### Scaling For Performance Testing

* You may scale the number of passive nodes by adjusting the `#count` passed to the `passive` job in `deploy.cue`.
* In the same fashion, you can scale the number of bootstrap nodes by defining more miners.
  * Pre-existing `enode-hash`, `key` and `coinbase` state needs to be created prior to deploying bootstrap nodes.
  * This state will be re-used across deployments and persists in the Vault `kv` store.
  * Additional bootstrap miner state only needs to be generated if the total number to be scaled to exceeds the number which currently exists (5 at the time of writing).
  * Pre-existing bootstrap node state can be viewed at the [testnet Vault kv](https://vault.mantis.ws/ui/vault/secrets/kv/list/nomad-cluster/testnet/) path.
  * This state pre-generation is done with the following command:
    ```
    nix run .#generate-mantis-keys $NAMESPACE $TOTAL_NUM_MANTIS_BOOTSTRAP_NODES $TOTAL_NUM_OBFT_NODES
    ```
    `NANESPACE` being `"testnet"` for the main `mantis-testnet` or your personal testnet name.




### Scaling Infrastructure Requirements

* If the mantis job definition is changed to require more Nomad client server infrastructure than is currently available, DevOps will deploy more infrastructure to host the additional Mantis taskgroups.


### Consul Templating

* Consul templates provide a powerful manner to extract real-time information about the mantis-ops cluster and services.
* Consul templates are described at their github repository [README.md](https://github.com/hashicorp/consul-template/blob/master/README.md) and utilize the [Go Template Format](https://golang.org/pkg/text/template/).

* At the time of writing, the templates in the `templates` dir are no longer useful but are left as an example to the user.
