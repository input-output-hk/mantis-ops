{ ... }: {
  services.ingress.extraConfig = ''
    backend mantis_1
      default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
      server mantis-1 mantis-1.mantis-miner.service.consul

    backend mantis_2
      default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
      server mantis-2 mantis-2.mantis-miner.service.consul

    backend mantis_3
      default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
      server mantis-3 mantis-3.mantis-miner.service.consul

    backend mantis_4
      default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
      server mantis-4 mantis-4.mantis-miner.service.consul

    frontend mantis_1
      mode tcp
      option tcplog
      bind *:9001
      default_backend mantis_1

    frontend mantis_2
      mode tcp
      option tcplog
      bind *:9002
      default_backend mantis_2

    frontend mantis_3
      mode tcp
      option tcplog
      bind *:9003
      default_backend mantis_3

    frontend mantis_4
      mode tcp
      option tcplog
      bind *:9004
      default_backend mantis_4
  '';
}
