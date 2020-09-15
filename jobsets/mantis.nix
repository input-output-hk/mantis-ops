{ declInput, pullRequestsJSON }:

import ./jobsets.nix {
  inherit declInput pullRequestsJSON;
  repo = "git@github.com:input-output-hk/mantis";
  branches = [ "develop" ];
}
