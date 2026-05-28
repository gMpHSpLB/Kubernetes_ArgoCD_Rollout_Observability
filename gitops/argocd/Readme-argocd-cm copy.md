<!-- Important changes:

Added url and accounts.admin, which are commonly present and well-tested in examples.

Fixed the clusters line to be pure text https://kubernetes.default.svc (no markdown-style [https://...]()).

Temporarily removed resource.customizations.health to keep things as simple and close to upstream as possible during recovery. 
Key change:

Removed cluster.inClusterEnabled: "true". -->
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: http://argocd-server.argocd.svc.cluster.local
  accounts.admin: apiKey,login

  kustomize.buildOptions: --load-restrictor LoadRestrictionsNone

  resource.exclusions: |
    - apiGroups:
        - apiextensions.k8s.io
      kinds:
        - CustomResourceDefinition
      clusters:
        - https://kubernetes.default.svc
      name: "*monitoring.coreos.com"