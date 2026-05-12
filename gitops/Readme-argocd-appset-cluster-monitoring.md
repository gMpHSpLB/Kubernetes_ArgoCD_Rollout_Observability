---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-monitoring-infra-environments
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions:
    - missingkey=error
  generators:
    - list:
        elements:
          - environment: dev
            namespace: monitoring
            targetRevision: main
            valuesFile: "kube-prometheus-stack-values-dev.yaml"
          - environment: staging
            namespace: monitoring
            targetRevision: main
            valuesFile: "kube-prometheus-stack-values-staging.yaml"
          - environment: prod
            namespace: monitoring
            targetRevision: main
            valuesFile: "kube-prometheus-stack-values-prod.yaml"
  template:
    metadata:
      name: cluster-monitoring-infra-{{.environment}}
      labels:
        app.kubernetes.io/part-of: myapp
        app.kubernetes.io/component: cluster-monitoring
        app.kubernetes.io/environment: "{{.environment}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/gMpHSpLB/pythonworkspace.git
        targetRevision: "{{.targetRevision}}"
        path: infra/k8s/monitoring
        helm:
          valueFiles:
            - "{{.valuesFile}}"
      destination:
        # If each Argo CD instance runs in its own cluster:
        server: https://kubernetes.default.svc
        namespace: "{{.namespace}}"
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
  templatePatch: |
    {{- if eq .environment "prod" }}
    spec:
      syncPolicy:
        automated: null
    {{- else }}
    spec:
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
    {{- end }}

What this gives you:

Creates three Applications:

    cluster-monitoring-infra-dev with kube-prometheus-stack-values-dev.yaml

    cluster-monitoring-infra-staging with kube-prometheus-stack-values-staging.yaml

    cluster-monitoring-infra-prod with kube-prometheus-stack-values-prod.yaml

All three deploy from infra/k8s/monitoring into the monitoring namespace.

Dev/staging are auto‑sync/prune/self‑heal; prod is manual (via the templatePatch).


If you run a single central Argo CD managing multiple clusters, you can add clusterUrl per element and use it to set .spec.destination.server, similar to the pattern here

Example generator elements for multi‑cluster:

generators:
  - list:
      elements:
        - environment: dev
          namespace: monitoring
          targetRevision: main
          valuesFile: "kube-prometheus-stack-values-dev.yaml"
          clusterUrl: "https://dev-api:6443"
        - environment: staging
          namespace: monitoring
          targetRevision: main
          valuesFile: "kube-prometheus-stack-values-staging.yaml"
          clusterUrl: "https://staging-api:6443"
        - environment: prod
          namespace: monitoring
          targetRevision: main
          valuesFile: "kube-prometheus-stack-values-prod.yaml"
          clusterUrl: "https://prod-api:6443"

and in template.spec.destination:
destination:
  server: "{{.clusterUrl}}"
  namespace: "{{.namespace}}"