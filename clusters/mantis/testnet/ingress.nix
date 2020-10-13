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

    backend mantis_5
      default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
      server mantis-5 mantis-5.mantis-miner.service.consul

    backend mantis_6
      default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
      server mantis-6 mantis-6.mantis-miner.service.consul

    backend mantis_7
      default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
      server mantis-7 mantis-7.mantis-miner.service.consul

    backend mantis_8
      default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
      server mantis-8 mantis-8.mantis-miner.service.consul

    backend mantis_9
      default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
      server mantis-9 mantis-9.mantis-miner.service.consul

    backend mantis_10
      default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
      server mantis-10 mantis-10.mantis-miner.service.consul

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

    frontend mantis_5
      mode tcp
      option tcplog
      bind *:9005
      default_backend mantis_5

    frontend mantis_6
      mode tcp
      option tcplog
      bind *:9006
      default_backend mantis_6

    frontend mantis_7
      mode tcp
      option tcplog
      bind *:9007
      default_backend mantis_7

    frontend mantis_8
      mode tcp
      option tcplog
      bind *:9008
      default_backend mantis_8

    frontend mantis_9
      mode tcp
      option tcplog
      bind *:9009
      default_backend mantis_9

    frontend mantis_10
      mode tcp
      option tcplog
      bind *:9010
      default_backend mantis_10
  '';
}
