let
  sources = import ../nix/sources.nix;
  pkgs = import sources.nixpkgs { };

in
with pkgs.lib;

{ repo
, declInput
, pullRequestsJSON
, pullRequests ? importJSON pullRequestsJSON
, branches ? [ ]
, extraInputs ? { }
}:
let
  mkJobset = rev: description: {
    inherit description;

    enabled = 1;
    hidden = false;
    nixexprinput = "src";
    nixexprpath = "release.nix";
    checkinterval = 30;
    schedulingshares = 100;
    enableemail = true;
    emailoverride = "";
    keepnr = 3;

    inputs = {
      src = {
        type = "git";
        value = "${repo} ${rev}";
        emailresponsible = true;
      };

      supportedSystems = {
        type = "nix";
        value = ''[ "x86_64-linux" "x86_64-darwin" ]'';
        emailresponsible = false;
      };
    } // extraInputs;
  };

  mkBranchJobset = branch: mkJobset branch "${branch} branch";

  mkPRJobset =
    prNumber: { title, ... }:
    nameValuePair "pr-${prNumber}" (mkJobset "pull/${prNumber}/head" title);

  branchJobsets = genAttrs branches mkBranchJobset;
  prJobsets = mapAttrs' mkPRJobset pullRequests;

  allJobsets = branchJobsets // prJobsets;

in
{
  jobsets = pkgs.runCommand "spec.json"
    { } ''
    cat <<EOF
    ${builtins.toXML declInput}
    EOF

    cat > $out <<EOF
    ${builtins.toJSON allJobsets}
    EOF
  '';
}
