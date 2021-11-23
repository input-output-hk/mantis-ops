let
  c = "create";
  r = "read";
  u = "update";
  d = "delete";
  l = "list";
  s = "sudo";

  secretsFolder = "encrypted";
  starttimeSecretsPath = "kv/nomad-cluster";
  runtimeSecretsPath = "runtime";
in
{
  # cluster level
  # --------------
  tf.hydrate.configuration = {
    data.vault_policy_document.admin.rule = [
      { path = "${runtimeSecretsPath}/*"; capabilities = [ c r u d l ]; }
      { path = "auth/userpass/users/*"; capabilities = [ c r u d l ]; }
      { path = "sys/auth/userpass"; capabilities = [ c r u d l s ]; }
    ];
    resource.vault_policy.read-iohk-testnet = {
      name = "read-iohk-testnet";
      policy = builtins.toJSON {
        path."${runtimeSecretsPath}/*/signer".capabilities = [ r l ];
      };
    };

    resource.vault_auth_backend.userpass = {
      type = "userpass";
    };
    resource.vault_mount.${runtimeSecretsPath} = {
      path = "${runtimeSecretsPath}";
      type = "kv-v2";
      description = "Applications can access runtime secrets if they have access credentials for them";
    };
  };
}
