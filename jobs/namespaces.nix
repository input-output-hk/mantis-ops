{ mkNomadJob, domain, lib, mantis, mantis-source, mantis-faucet
, mantis-faucet-source, morpho-node, morpho-source, dockerImages
, mantis-explorer }@args:
let
  namespaces = {
    #mantis-evm = import ./mantis {
    #  namespace = "mantis-evm";
    #  vm = evm;
    #  publicPortStart = 9100;
    #};

    #mantis-iele = import ./mantis {
    #  namespace = "mantis-iele";
    #  vm = iele;
    #  publicPortStart = 9200;
    #};

    mantis-iele = import ./mantis (args // {
      namespace = "mantis-iele";
      publicPortStart = 10000;
      domainSuffix = "-iele.${domain}";

      extraConfig = ''
        mantis.vm {
          mode = "external"
          external {
            vm-type = "kevm"
            run-vm = true
            executable-path = "/bin/kevm-vm"
            host = "127.0.0.1"
            port = {{ env "NOMAD_PORT_vm" }}
          }
        }
      '';
    });
    mantis-kevm = import ./mantis (args // {
      namespace = "mantis-kevm";
      publicPortStart = 9000;
      domainSuffix = "-kevm.${domain}";

      extraConfig = ''
        mantis.vm {
          mode = "external"
          external {
            vm-type = "kevm"
            run-vm = true
            executable-path = "/bin/kevm-vm"
            host = "127.0.0.1"
            port = {{ env "NOMAD_PORT_vm" }}
          }
        }
      '';
    });
  };
in builtins.foldl' (s: v: s // v) {} (builtins.attrValues namespaces)
