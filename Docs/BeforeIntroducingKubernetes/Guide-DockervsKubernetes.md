When to use Docker vs Kubernetes
The short mental model:

Docker: build and run containers on a single machine. Great for local dev, CI, single‑host deployments, and artifact standardization.

Kubernetes: orchestrate containers across many machines. Great for production/staging, high availability, scaling, and advanced deployment strategies like blue‑green, canary, and auto‑rollback.

More concretely for your stack:

Use Docker (and Docker Compose) for
Local development:

dev-up, dev-down with your compose files.

Fast feedback, simple to run on your laptop.

CI integration testing:

make test-docker plus docker-compose.yml to spin up db + services for tests.

No need to connect to a real cluster for unit/integration tests.

Image build & scan:

Build images with your optimized, hardened Dockerfiles.

Run Safety and Docker Scout; push tagged images to GHCR.

Docker here is your image factory and test harness.

Use Kubernetes for
Staging/production runtime:

Run myapp and mylearning in a cluster with Deployments/Services/Ingress.

Use resource requests/limits, autoscaling, and pod health management.

Blue‑Green / Canary / auto‑rollback:

Blue‑Green via two Deployments and a single Service selector.

Canary + auto‑rollback via Argo Rollouts using your existing Prometheus metrics.

Kubernetes here is your runtime orchestrator and deployment engine.