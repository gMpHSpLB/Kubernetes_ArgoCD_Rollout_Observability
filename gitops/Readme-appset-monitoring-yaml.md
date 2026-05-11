# This ArgoCD ApplicationSet manages your main application 
# (the myapp Helm chart) across environments. Big upgrade 
# from the previous ones - it uses Helm with environment-specific 
# values files!
#
# What it does
#   - Creates 3 Applications: myapp-dev, myapp-staging, myapp-prod
#   - Deploys your myapp Helm chart from charts/myapp
#   - Uses separate values files per environment: 
#     environments/dev/values-myapp.yaml, etc.
#   - Each deploys to its own dedicated namespace 
#     (myapp-dev, myapp-staging, myapp-prod)
# Why use it?
#   - Environment isolation: Each env in separate namespace (security, resource quotas)
#   - Helm values per env: Different replicas, resources, config for dev/staging/prod
#   - Production-ready: Manual sync for prod + tag promotion capability
# Result: 3 Isolated Environments
# | App           | Namespace     | Values File               | Auto-sync |
# | ------------- | ------------- | ------------------------- | --------- |
# | myapp-dev     | myapp-dev     | dev/values-myapp.yaml     | ✅         |
# | myapp-staging | myapp-staging | staging/values-myapp.yaml | ✅         |
# | myapp-prod    | myapp-prod    | prod/values-myapp.yaml    | ❌ Manual  |
#
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-app-environments # Manages the main app (not infra)
  namespace: argocd
spec: # Standard header - focuses on your core application.
  goTemplate: true
  goTemplateOptions:
    - missingkey=error
  generators:
    - list:
        elements:
          - environment: dev
            namespace: myapp-dev # ← **Separate NS per env**
            autoSync: "true"
            targetRevision: main
            myappValuesFile: "../../environments/dev/values-myapp.yaml" # ← **Env-specific values**
          - environment: staging
            namespace: myapp-staging
            autoSync: "true"
            targetRevision: main
            myappValuesFile: "../../environments/staging/values-myapp.yaml"
          - environment: prod
            namespace: myapp-prod
            autoSync: "false"
            targetRevision: main           # later: vX.Y.Z for prod
            myappValuesFile: "../../environments/prod/values-myapp.yaml"
# Generator - 3 key differences:
#   1. Unique namespaces per env
#   2. myappValuesFile variable for Helm values
#   3. Path ../../environments/{env}/values-myapp.yaml (relative to charts/myapp)
  template:
    metadata: # Template - labels it as application component (vs monitoring/logging).
      name: myapp-{{environment}} # Clean names: myapp-dev, etc.
      labels:
        app.kubernetes.io/part-of: myapp
        app.kubernetes.io/component: application # ← App vs infra
        app.kubernetes.io/environment: "{{environment}}"
    spec:
      project: default
      source: # Source - Helm-powered:
        repoURL: git@github.com:gMpHSpLB/pythonworkspace.git
        targetRevision: "{{targetRevision}}"
        path: charts/myapp # ← **Helm chart path**
        helm:
          valueFiles:
            - "{{myappValuesFile}}" # Uses env-specific values from generator
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{namespace}}" # Per-environment namespaces - complete isolation. myapp-dev, myapp-staging, myapp-prod
      syncPolicy:
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