# This is another ArgoCD ApplicationSet - almost identical to the 
# monitoring one, but for your logging stack (likely Loki, Promtail, etc.). It follows the exact same pattern.
#
# What it does
#   - Creates 3 ArgoCD Applications: myapp-logging-dev, myapp-logging-staging, 
#     myapp-logging-prod
#   - Deploys logging resources from infra/k8s/logging path in your Git repo
#   - All target the logging namespace with same sync policies 
#     (auto for dev/staging, manual for prod)
#
# Why use it?
# Same reasons as monitoring:
#    - Single manifest manages all logging environments
#    - Consistent GitOps across your observability stack
#    - Easy tag promotion for prod (main → v1.2.3)
#
# Key Differences from Monitoring ApplicationSet
# | Aspect          | Monitoring                    | Logging                    |
# | --------------- | ----------------------------- | -------------------------- |
# | Name            | myapp-monitoring-environments | myapp-logging-environments |
# | Namespace       | monitoring                    | logging                    |
# | Component label | monitoring                    | logging                    |
# | Git path        | infra/k8s/monitoring          | infra/k8s/logging          |
# | Generated Apps  | myapp-monitoring-*            | myapp-logging-*            |
#
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-logging-environments # Different name from monitoring
  namespace: argocd
spec: # Standard header - unique name distinguishes it from monitoring ApplicationSet.
  goTemplate: true
  goTemplateOptions:
    - missingkey=error
  generators: # Generator - identical pattern, just namespace: logging instead of monitoring.
    - list:
        elements:
          - environment: dev
            namespace: logging   # ← **Key difference**: logging namespace
            autoSync: "true"
            targetRevision: main
          - environment: staging
            namespace: logging
            autoSync: "true"
            targetRevision: main
          - environment: prod
            namespace: logging
            autoSync: "false"
            targetRevision: main    # later: vX.Y.Z
  template:
    metadata: # Template metadata - same labeling pattern, component: logging.
      name: myapp-logging-{{environment}} # Generates logging-* names
      labels:
        app.kubernetes.io/part-of: myapp
        app.kubernetes.io/component: logging # ← **Different component**
        app.kubernetes.io/environment: "{{environment}}"
    spec:
      project: default
      source: # Source - points to infra/k8s/logging directory (your Loki/Promtail manifests).
        repoURL: git@github.com:gMpHSpLB/pythonworkspace.git
        targetRevision: "{{targetRevision}}"
        path: infra/k8s/logging # ← **Different path**: logging manifests
      destination: # Destination - deploys to logging namespace.
        server: https://kubernetes.default.svc
        namespace: "{{namespace}}" # Resolves to 'logging'
      syncPolicy: # IDENTICAL to monitoring, Same sync logic - auto-sync for dev/staging, manual for prod.
        syncOptions:
          - CreateNamespace=true
  templatePatch: |
    {{- if eq .autoSync "true" }}
    spec:
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
    {{- end }}