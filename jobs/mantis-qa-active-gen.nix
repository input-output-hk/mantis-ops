{ mkNomadJob, dockerImages }:
let namespace = "mantis-qa-load";
in {
  "${namespace}-active-gen" = mkNomadJob "active-gen" {
    datacenters = [ "eu-central-1" "us-east-2" ];
    inherit namespace;

    taskGroups.active-gen = {
      tasks.active-gen = {
        driver = "docker";
        config = { image = dockerImages.mantis-active-gen.id; };

        templates = [{
          data = ''
            {}
          '';
          destination = "local/testnet.json";
        }];
      };
    };
  };
}
