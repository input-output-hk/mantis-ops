{ ... }: {
  services.ingress.extraConfig = ''
    {{ range services -}}
      {{ if .Tags | contains "public" }}
        {{ range service .Name }}
    backend  {{ .ID | replaceAll "-" "_" }}
      mode tcp
      server {{ .ID }} {{ .Address }}:{{ .Port }}
        {{ end }}

        {{ range service .Name }}
    frontend {{ .ID | replaceAll "-" "_" }}
      mode tcp
      option tcplog
      bind *:{{ .ServiceMeta.Port }}
      default_backend {{ .ID | replaceAll "-" "_" }}
        {{ end }}
      {{- end }}
    {{- end }}
  '';
}
