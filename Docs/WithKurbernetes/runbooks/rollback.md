# Rollback Runbook

This document describes how to rollback a bad deployment for `myapp`.

## 1. Recommended order

1. **Detect failure**  
   - CI/CD dev job fails (smoke, observability, or rollout health).
   - Argo CD / Argo Rollouts show degraded status.

2. **Immediate mitigation (cluster-level)**  
   - Use Argo Rollouts undo to restore the previous revision in dev:
     ```bash
     kubectl argo rollouts get rollout myapp-dev-myapp -n myapp-dev
     kubectl argo rollouts undo rollout myapp-dev-myapp -n myapp-dev
     ```

3. **Permanent fix (Git-first)**  
   - Revert the Git commit that introduced the bad image/config.
   - Push the revert or open a rollback PR.
   - Let Argo CD reconcile the reverted state.

4. **Verify**  
   - Check rollout and pods:
     ```bash
     kubectl argo rollouts get rollout myapp-dev-myapp -n myapp-dev
     kubectl get pods -n myapp-dev
     ```
   - Confirm CI dev job passes again on the next run.

---

## 2. Git rollback (GitOps-first)

### Simple revert on main

```bash
git log --oneline --decorate -n 10
git revert <bad-commit-sha>
git push origin main
```

Use when:
- main is protected by CI and you want an immediate revert on main.

### Rollback via PR

```bash
git checkout -b rollback/<short-name>
git revert <bad-commit-sha>
git push origin rollback/<short-name>
# Open PR "Rollback: <short-name>" in GitHub UI
```

Use when:
- you require review for every change on main.

---

## 3. Kubernetes / Argo Rollouts rollback (emergency)

### Dev Rollout (preferred for dev)

```bash
kubectl argo rollouts get rollout myapp-dev-myapp -n myapp-dev
kubectl argo rollouts undo rollout myapp-dev-myapp -n myapp-dev
# or to a specific revision:
kubectl argo rollouts undo rollout myapp-dev-myapp -n myapp-dev --to-revision=<rev>
```

### Deployment rollback (if any plain Deployments remain)

```bash
kubectl -n <namespace> rollout undo deployment/myapp
# or:
kubectl -n <namespace> rollout undo deployment/myapp --to-revision=<n>
```

> **Important**: After an emergency cluster rollback, always fix Git (via revert/PR), otherwise Argo CD might reapply the bad change on the next sync.

---

## 4. CI/CD behaviour

The dev CI job:

1. Builds and pushes `myapp:dev`.
2. Updates the Argo CD parameter for `myapp-dev`.
3. Waits for rollout health.
4. Runs smoke and observability checks.
5. On failure:
   - calls `make k8s-rollout-undo-myapp-dev` (cluster rollback),
   - writes a rollback report artefact,
   - fails the job,
   - sends a notification (Slack/Teams).

Rollback report includes:
- environment,
- commit SHA,
- image tag,
- rollout status,
- smoke-test result,
- rollback action taken,
- timestamp.

Use this report for incident review and debugging.