# infra/k8s/monitoring/values.yaml
# Shared defaults across dev/staging/prod. Env-specific overrides live in
# kube-prometheus-stack-values-*.yaml files.
# Two important points:
#   - Because your kube-prometheus-stack-values-*.yaml are already 
#   written exactly for the upstream chart, you don’t need to nest 
#   them under kube-prometheus-stack: in those files; Argo CD will 
#   pass them directly to the dependency chart as override files.
#
#   - You don’t need to run helm dependency update manually for Argo CD; 
#   it will resolve the dependencies automatically.
global:
  # default environment; safe to keep as dev or generic
  environment: dev

kube-prometheus-stack:
  # You can move your existing top-level keys under this if you want,
  # but since your values files are already shaped for the upstream chart,
  # we can simply keep them as-is and not put much here at first.
  enabled: true

