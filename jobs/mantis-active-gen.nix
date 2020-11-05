{ mkNomadJob, dockerImages, namespace ? "mantis-qa-load" }: {
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
