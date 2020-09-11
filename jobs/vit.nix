{ mkNomadJob, systemdSandbox, writeShellScript, coreutils, lib,
, wget, gzip, gnutar, cacert }:
let
  run-mantis = writeShellScript "mantis" ''
    exec ${mantis}/bin/mantis-core
  '';
in {
  vit = mkNomadJob "vit" {
    datacenters = [ "us-east-2" ];
    type = "service";

    taskGroups.vit-servicing-station = {
      count = 1;
      services.vit-servicing-station = { };
      tasks.vit-servicing-station = systemdSandbox {
        name = "vit-servicing-station";
        command = run-vit;

        env = { PATH = lib.makeBinPath [ coreutils ]; };

        resources = {
          cpu = 100;
          memoryMB = 1024;
        };
      };
    };

    taskGroups.jormungandr = {
      count = 1;

      services.jormungandr = { };

      tasks.jormungandr = systemdSandbox {
        name = "jormungandr";

        command = run-jormungandr;

        env = {
          PATH = lib.makeBinPath [ coreutils wget gnutar gzip ];
          SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
        };

        resources = {
          cpu = 100;
          memoryMB = 1024;
        };
      };
    };
  };
}
