{ config, ... }: {
  # services.ingress.extraHttpsAcls = ''
  #   acl is_explorer_web hdr(host) -i explorer.${config.cluster.domain}
  #   acl is_explorer_rpc path_beg -i /rpc/node
  #   acl is_faucet_rpc hdr(host) -i faucet.${config.cluster.domain}
  # '';

  services.ingress-config.extraHttpsBackends = ''
    {{ range services -}}
      {{ if .Tags | contains "ingress" -}}
        {{ range service .Name -}}
          {{ if (and (eq .ServiceMeta.IngressBind "*:443") .ServiceMeta.IngressServer) -}}
            use_backend {{ .ID }} if { hdr(host) -i {{ .ServiceMeta.IngressHost }} } {{ .ServiceMeta.IngressIf }}
          {{ end -}}
        {{ end -}}
      {{ end -}}
    {{ end -}}
  '';

    # backend explorer_web
    #   default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip check maxconn 2000
    #   server explorer-web _testnet-explorer._tcp.service.consul
    #
    # backend explorer_rpc
    #   mode http
    #   default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip check maxconn 2000
    #   http-request set-path /
    #   server-template explorer-rpc 2 _testnet-mantis-passive-rpc._tcp.service.consul
    #
    # backend faucet_rpc
    #   mode http
    #   default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip maxconn 2000
    #   server-template faucet-rpc 2 _testnet-mantis-faucet._tcp.service.consul


  services.ingress-config.extraConfig = ''
    {{- range services -}}
      {{ if .Tags | contains "ingress" -}}
        {{ range service .Name -}}
          {{ if .ServiceMeta.IngressServer -}}
            backend {{ .ID }}
              mode {{ or .ServiceMeta.IngressMode "http" }}
              default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
              {{ .ServiceMeta.IngressBackendExtra }}
              server {{.ID}} {{ .ServiceMeta.IngressServer }}

            {{ if (and .ServiceMeta.IngressBind (ne .ServiceMeta.IngressBind "*:443") ) }}
              frontend {{ .ID }}
                bind {{ .ServiceMeta.IngressBind }}
                mode {{ or .ServiceMeta.IngressMode "http" }}
                default_backend {{ .ID }}
            {{ end }}
          {{ end -}}
        {{ end -}}
      {{ end -}}
    {{ end }}
  '';
}
