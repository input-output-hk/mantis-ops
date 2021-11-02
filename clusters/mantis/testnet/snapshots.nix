{ config, lib, ... }: {
  services.consul-snapshots.hourly =
    lib.recursiveUpdate config.services.consul-snapshots.hourly {
      backupCount = 6;
    };
}
