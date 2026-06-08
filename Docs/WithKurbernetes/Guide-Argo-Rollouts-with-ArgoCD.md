1. High‑level plan (specific to your repo)
Install Argo Rollouts into your Minikube cluster.

Add useArgoRollouts to charts/myapp/values.yaml and environments/*/values-myapp.yaml.

Add a Rollout template to charts/myapp/templates/ and gate it with useArgoRollouts.

Wire Prometheus via an AnalysisTemplate in infra/k8s/ for staging.

Adjust ArgoCD app / ApplicationSet so it applies the Rollout + analysis YAML from Git.

Update Make targets to observe rollouts (not to drive them).

ArgoCD continues to reconcile from Git; Rollouts handles the progressive delivery and metrics‑based decisions.