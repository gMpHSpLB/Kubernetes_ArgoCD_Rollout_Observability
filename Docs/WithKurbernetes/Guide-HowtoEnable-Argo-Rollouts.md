useArgoRollouts: false

rollouts:
strategy: canary
canary:
steps:
- setWeight: 10
- pause:
duration: 120
- setWeight: 25
- pause:
duration: 120
- setWeight: 50
- pause:
duration: 120
- setWeight: 100
analysis:
enabled: true
templateName: myapp-canary-analysis
===========================================================================================================
Details:
What this config does

This is a Helm values.yaml snippet for a chart that can optionally use Argo Rollouts (an enhanced Kubernetes controller that provides advanced deployment strategies such as Canary and BlueGreen).

The top-level flag useArgoRollouts: false toggles whether the chart should deploy Rollout objects (Argo Rollouts) instead of plain Deployments.

The rollouts: block configures a canary rollout strategy and analysis for Argo Rollouts:

strategy: canary — choose the canary strategy.

canary.steps — a series of incremental traffic-weight changes and pauses:

setWeight: 10 — send 10% of traffic to the new replica set.

pause duration: 120 — wait 120 seconds.

setWeight: 25 — raise to 25% traffic.

pause 120s.

setWeight: 50 — raise to 50%.

pause 120s.

setWeight: 100 — route all traffic to the new version.

analysis.enabled: true — enable automated analysis during the canary.

analysis.templateName: myapp-canary-analysis — refer to an Argo Rollouts AnalysisTemplate named myapp-canary-analysis to run metrics checks or webhooks at analysis points.

Typical use case

Safe progressive delivery / canary releases: gradually shift traffic to a new application version while validating health and metrics to reduce blast radius from bad changes.

Automated verification: Argo Rollouts analysis allows you to abort or promote the canary based on metrics (errors, latency, custom Prometheus queries, webhooks).

Environments: useful in staging and production to control risk; in development teams you might still use it for realistic testing of release mechanics.

How to enable for dev / staging / prod
You need three pieces:

Chart templates that render either a Deployment or an Argo Rollout depending on useArgoRollouts.

Argo Rollouts controller installed in the cluster.

An AnalysisTemplate (myapp-canary-analysis) present in the cluster or created by the chart.

Steps to implement and enable per environment

Chart templating (example approach)

Your Helm templates should conditionally render either:

a Kubernetes Deployment when .Values.useArgoRollouts is false, or

an Argo Rollouts Rollout resource when true, using .Values.rollouts.* for strategy and analysis.

Example logic (pseudocode for templates):

if .Values.useArgoRollouts

render rollout.yaml with .spec.strategy.canary.steps from .Values.rollouts.canary.steps and .spec.analysis from .Values.rollouts.analysis

else

render standard deployment.yaml

Install Argo Rollouts controller

Cluster-level: install Argo Rollouts (kubectl/Helm):

kubectl create namespace argo-rollouts

kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

Confirm controller running: kubectl get pods -n argo-rollouts

Provide the AnalysisTemplate

Create an AnalysisTemplate named myapp-canary-analysis that defines metrics to check (Prometheus queries, webhooks, or Kubernetes checks) and success/failure criteria.

Example minimal AnalysisTemplate (concept):

metrics: Prometheus query for error rate < threshold, latency < threshold

failure/success conditions

You can ship this template with your chart (templates/analysis-template.yaml) or manage it separately via GitOps (ArgoCD).

Enable per environment

Use environment-specific values files (values-dev.yaml, values-staging.yaml, values-prod.yaml) or override values in your CI/CD:

For dev: maybe keep useArgoRollouts: false (faster iteration), or enable a very short canary (smaller pauses).

For staging: enable Argo Rollouts to validate the process with smaller traffic weights and possibly fewer pauses.

For prod: enable Argo Rollouts with full analysis, longer pauses and production-grade AnalysisTemplate (Prometheus metrics, SLO-based thresholds).

Example values (values-staging.yaml):

useArgoRollouts: true

rollouts:
strategy: canary
canary:
steps:

setWeight: 10

pause: { duration: 60 }

setWeight: 50

pause: { duration: 120 }

setWeight: 100
analysis:
enabled: true
templateName: myapp-canary-analysis

Deploy with Helm / GitOps

Helm CLI: helm upgrade --install myapp ./charts/myapp -f values-prod.yaml

GitOps (ArgoCD): commit the chosen values file or Kustomize overlay per environment. Ensure ArgoCD has permissions and target cluster has Argo Rollouts installed.

Practical tips

    Test AnalysisTemplate locally in staging before enabling it in prod.

    Use Prometheus queries in analysis that return numeric values and clear pass/fail criteria.

    Keep pause durations reasonable; long pauses increase time-to-release.

    Use small initial setWeight in production to reduce blast radius.

    Monitor Rollout status: kubectl argo rollouts get rollout <name> --watch (requires argo-rollouts kubectl plugin).

If you need traffic routing, ensure your Ingress/Service mesh (Istio, Linkerd) or Service configuration supports weight-based routing. Argo Rollouts can shift traffic using Service selectors for simple cases, or integrate with service meshes via plugins.
