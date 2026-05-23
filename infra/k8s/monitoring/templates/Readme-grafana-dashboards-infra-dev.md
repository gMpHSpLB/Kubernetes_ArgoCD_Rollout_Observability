{{- if eq .Values.global.environment "dev" }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards-infra-dev # must match dashboardsConfigMaps.infra from infra/k8s/monitoring/kube-prometheus-stack-values-prod.yaml
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
# Each key (home.json, k8s-overview.json) is a dashboard 
# file. Value is raw JSON (minified or compact is fine).
data:
  home.json: |
{{ .Files.Get "grafana/dashboards/dev/infra/home.json" | indent 4 }}
  k8s-overview.json: |
{{ .Files.Get "grafana/dashboards/dev/infra/k8s-overview.json" | indent 4 }}
{{- end }}