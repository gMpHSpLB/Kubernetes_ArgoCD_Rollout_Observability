You only need to resync all three (app, monitoring, logging) in certain situations. Think in terms of “when is the rendered desired state or runtime behavior for this environment actually different now?”

Here are the main scenarios.

1) After changing repo access or URL
Resync all three when:

    You change repo credentials (SSH→HTTPS+PAT, new PAT, new deploy key, etc.).

    You change the repoURL in the ApplicationSet or Application (e.g., move to another repo or HTTPS URL).

Reason: Argo CD must re-render manifests from the repo with the new configuration and clear Unknown/comparison errors.

Action per env:

    make argocd-sync-dev
    make argocd-sync-staging
    make argocd-sync-prod (when you actually want to deploy prod)

2) When Git manifests change for that environment
Any time you merge changes that affect manifests for an environment, you should sync the relevant apps for that env:

    Changes to charts/myapp or its templates.

    Changes to monitoring/logging charts or Kustomize overlays.

    Changes to values-*.yaml for that environment (dev/staging/prod).

If auto-sync is enabled, Argo CD will sync automatically; if not (like your prod), you manually trigger sync.

Action:

    For dev changes: make argocd-sync-dev (this already syncs app+monitoring+logging).

    For staging: make argocd-sync-staging.

    For prod: make argocd-sync-prod when you’re ready to promote.

You don’t have to sync other environments if their manifests didn’t change.

3) After ApplicationSet template or generator changes
When you edit the ApplicationSet that generates myapp-*, myapp-monitoring-*, myapp-logging-*, such as:

    Changing destination.namespace or cluster server.

    Changing helm.valueFiles template.

    Adding/removing environments or renaming Applications.

The ApplicationSet controller will update the child Applications, but Argo CD still needs a sync to apply any differences to the cluster.

Action:

    For each env impacted by the changed template, run argocd-sync-* (or your smoke target) once.

4) After cluster-level or infra changes that require reapply
Examples:

You changed a CRD version or removed/re-installed operators that monitoring/logging depends on.

You changed something out-of-band (kubectl, Helm) that conflicts with Git state.

In these cases, a sync is a clean way to reassert Git as source of truth and reconcile drift.

Action:

Sync whichever apps are affected:

    CRD change for logging stack → sync myapp-logging-* per env.

    Global infra change for monitoring → sync myapp-monitoring-*.

    If in doubt, run your existing argocd-sync-<env> which covers all three.

5) When status is stuck or incorrect
If you see:

    SYNC STATUS: Unknown or weird ComparisonError.

    Health stuck in Progressing even after pods are actually ready.

A hard refresh + sync can clear cache issues and re-evaluate state.

Example (per app):

bash
kubectl annotate application myapp-dev -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
argocd app sync myapp-dev
Or just run your argocd-sync-<env> targets, which do a normal sync. Use this when you fix repo credentials, ApplicationSet template bugs, or chart bugs.

6) After manual out-of-band changes to monitored namespaces
If you:

    Manually scale deployments, change ConfigMaps/Secrets, or delete resources in myapp-dev, myapp-staging, or myapp-prod namespaces using kubectl or Helm directly.

Argo CD will detect drift and show OutOfSync. You should resync to bring the cluster back to the Git-defined state.

Action:

    For the affected env, make argocd-sync-dev / staging / prod.

When you do not need to resync
    Pure observability-only checks (e.g., you’re just viewing metrics/logs, not changing manifests).

    Changing things in other repos that are not referenced by these Applications.

    Restarting Argo CD pods without changing specs (Argo CD will refresh on its own schedule).

Given your Makefile structure, a good mental model:

    Bootstrap: make k8s-bootstrap-argocd → new cluster or after nuking argocd.

    Day-to-day deploys:

        After merging manifest changes: make argocd-sync-dev (and staging/prod as needed).

    End-to-end verification:

        make k8s-smoke-dev-argocd (or staging/prod) → sync + health checks + HTTP smokes.