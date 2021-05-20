{ pkgs, config, lib, self, ... }: {
  imports = [ (self.inputs.bitte + /profiles/glusterfs/client.nix) ];

  services.nomad.client = {
    chroot_env = {
      "/etc/passwd" = "/etc/passwd";
      "/etc/resolv.conf" = "/etc/resolv.conf";
      "/etc/services" = "/etc/services";
    };

    host_volume = [{
      rocksdb = {
        path = "/mnt/gv0/nomad/rocksdb";
        read_only = false;
      };
    }];
  };

  system.activationScripts.nomad-host-volumes-new = ''
    export PATH="${lib.makeBinPath (with pkgs; [ fd coreutils ])}:$PATH"
  '' + (lib.pipe config.services.nomad.client.host_volume [
    (map builtins.attrNames)
    builtins.concatLists
    (map (d: ''
      mkdir -p /mnt/gv0/nomad/${d}
      fd . -o root /mnt/gv0/nomad/${d} -X chown nobody:nogroup
    ''))
    (builtins.concatStringsSep "\n")
  ]);
}
