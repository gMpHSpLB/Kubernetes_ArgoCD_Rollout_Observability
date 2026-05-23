# Grafana admin credentials Secret (pstaging)
# Namespace: must match your monitoring namespace. You already have infra/k8s/monitoring/namespace.yaml, so use its metadata.name here.
# This secret is consumed by the existingSecret + userKey/passwordKey fields in kube-prometheus-stack-values-prod.yaml.
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin-credentials-staging
  namespace: monitoring
type: Opaque
stringData:
  admin-user: admin
  admin-password: admin # "CHANGE_ME_STRONG_PASSWORD"