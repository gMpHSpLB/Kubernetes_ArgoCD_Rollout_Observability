# The key parts:
#   - p, role:admin, applications, *, */*, allow – admin can sync/update/etc. all applications.
#   - g, admin, role:admin – maps the admin user to role:admin.
# If policy.csv is missing entirely, Argo CD falls back to its 
#  built‑in policy (which is fine). If you see a custom policy.csv 
#  but no g, admin, role:admin, your admin user may not be associated with the full admin role.
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    # Built-in admin role: full access to everything
    p, role:admin, applications, *, */*, allow
    p, role:admin, projects, *, *, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, accounts, *, *, allow

    # Optional: read-only role for future non-admin users
    p, role:readonly, applications, get, */*, allow

    # Map the built-in 'admin' user to role:admin
    g, admin, role:admin

  # If you later add SSO, these are the JWT/OIDC claim names you can use
  scopes: '[groups, email]'



  apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # No explicit rules; rely on default role
  policy.csv: ""
  policy.default: role:admin
  scopes: '[groups, email]'