Here’s a Prometheus + Grafana playbook

1. Files and layout you use
You follow this structure:

Docker/prometheus.yml – Prometheus scrape config.

Docker/grafana-datasource.yml – Grafana data source provisioning (Prometheus).

Docker/grafana-dashboards.yml – Grafana dashboard provisioning.

Docker/dashboards/myapp-observability.json – actual Grafana dashboard JSON.

myapp/src/myapp/metrics.py – FastAPI + Prometheus integration (middleware + /metrics endpoint).

myapp/src/myapp/main.py – FastAPI app, importing metrics_middleware and metrics_endpoint and exposing /metrics.

docker-compose.*.yml – services for myapp, prometheus, grafana on the same Docker network.

You also use APP_ENV (e.g. dev, staging, prod) as an env var passed into the metrics middleware.

2. FastAPI → Prometheus: metrics middleware and endpoint
2.1 Metrics middleware
In myapp/src/myapp/metrics.py you have:

A Prometheus registry and standard metrics (counters, histograms).

A metrics_middleware(app_env) factory that wraps each request and updates metrics.

Essentials:

python
# src/myapp/metrics.py (simplified)
from fastapi import Request, Response
from prometheus_client import Counter, Histogram, REGISTRY, generate_latest

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status", "env"],
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency (seconds)",
    ["method", "path", "env"],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5),
)


def metrics_middleware(app_env: str):
    async def middleware(request: Request, call_next):
        method = request.method
        path = request.url.path

        # Optional: normalize dynamic path segments here.

        with REQUEST_LATENCY.labels(
            method=method, path=path, env=app_env
        ).time():
            response = await call_next(request)

        REQUEST_COUNT.labels(
            method=method,
            path=path,
            status=response.status_code,
            env=app_env,
        ).inc()

        return response

    return middleware
This is exactly your existing pattern: per‑request metrics with labels (method, path, status, env) plus latency histograms.

2.2 /metrics endpoint
Also in metrics.py, you have:

python
# metrics_endpoint() in metrics.py
async def metrics_endpoint() -> Response:
    content = generate_latest(REGISTRY)
    return Response(
        content=content,
        media_type="text/plain; version=0.0.4",
    )
This serializes all registered Prometheus metrics (including your counters/histograms) in the text format Prometheus expects.

3. Wiring metrics into main.py
In myapp/src/myapp/main.py, you:

Import metrics_middleware and metrics_endpoint.

Attach metrics middleware with APP_ENV.

Expose /metrics endpoint that returns metrics_endpoint().

Pattern you use:

python
# src/myapp/main.py (simplified)
from fastapi import FastAPI, HTTPException, Request, Response
from myapp.metrics import metrics_endpoint, metrics_middleware
from myapp.logging_config import logging_middleware, setup_logging
from myapp.api.v1.routes import router as v1_router
...

def create_app() -> FastAPI:
    setup_logging()
    app = FastAPI(title=settings.app_name, lifespan=lifespan)

    app_env = os.getenv("APP_ENV", "dev")

    # Logging + Prometheus metrics middleware
    app.middleware("http")(logging_middleware)
    app.middleware("http")(metrics_middleware(app_env))

    app.include_router(v1_router, prefix="/api/v1")
    return app

app = create_app()

# /metrics exposes the updated values for Prometheus to scrape
@app.get("/metrics")
async def metrics():
    return await metrics_endpoint()
So:

Every request to any route passes through metrics_middleware, which updates your Prometheus metrics.

/metrics exposes these metrics in Prometheus format.

4. Prometheus configuration (Docker/prometheus.yml)
Your Docker/prometheus.yml file is:

text
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "myapp"
    metrics_path: /metrics
    static_configs:
      - targets:
          - "myapp:8000"
Key behavior:

Prometheus scrapes metrics every 15 seconds.

It calls http://myapp:8000/metrics inside the Docker network (myapp is the service name in Docker Compose).

Metrics from your FastAPI app (http_requests_total, http_request_duration_seconds, etc.) are stored in Prometheus.

5. Grafana provisioning (data source and dashboards)
5.1 Data source (Docker/grafana-datasource.yml)
You auto‑provision a Prometheus data source:

text
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
So when Grafana starts:

It automatically creates a Prometheus data source pointing at http://prometheus:9090.

It marks it as the default for new dashboards.

5.2 Dashboards provisioning (Docker/grafana-dashboards.yml)
You also auto‑load dashboards from a folder:

text
apiVersion: 1

providers:
  - name: default
    orgId: 1
    folder: ""
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
Grafana scans /var/lib/grafana/dashboards for JSON dashboards at startup and loads them automatically.

5.3 Dashboard JSON (Docker/dashboards/myapp-observability.json)
You have a ready‑made Grafana dashboard at:

Docker/dashboards/myapp-observability.json (panel definitions, PromQL queries, etc.).

Grafana mounts it into /var/lib/grafana/dashboards (via docker-compose) so this dashboard appears automatically.

6. How Docker Compose ties it together (pattern)
Your docker-compose.*.yml files (dev/staging/prod) follow this pattern:

myapp service:

Exposes port 8000.

Runs FastAPI app that serves /metrics.

Has APP_ENV=dev (or staging/prod).

prometheus service:

Uses prometheus.yml from Docker/prometheus.yml.

Scrapes myapp:8000/metrics.

grafana service:

Mounts grafana-datasource.yml and grafana-dashboards.yml.

Mounts Docker/dashboards/myapp-observability.json into /var/lib/grafana/dashboards.

Uses the Prometheus data source automatically.
7. How to test the whole setup step‑by‑step
4.1 Start everything
bash
make dev-up
Then confirm API is up:

bash
make check-api
# or manually:
curl -sf http://localhost:8000/docs
check-api loops and waits for /docs to return 200.

4.2 Generate traffic
You already have a helper target:

bash
make hit-api-multiple
Which runs:

bash
for i in {1..20}; do curl -s -o /dev/null http://localhost:8000/docs; done
You can also manually hit various routes:

bash
for i in {1..20}; do
  curl -s -o /dev/null http://localhost:8000/docs
  curl -s -o /dev/null http://localhost:8000/metrics
  curl -s -o /dev/null http://localhost:8000/api/v1/users || true  # example
done
Each request updates your Prometheus metrics via metrics_middleware.

4.3 Verify Prometheus sees metrics
Inside Prometheus UI (exposed via your docker-compose, usually on http://localhost:9090):

Open http://localhost:9090.

In “Graph” → “Expression” box, query:

text
http_requests_total
You should see series with labels like {method="GET", path="/docs", status="200", env="dev"}.

You can also test latency buckets:

text
http_request_duration_seconds_bucket
4.4 Verify Grafana dashboards
Grafana is usually on http://localhost:3000 (check your docker-compose).

Open http://localhost:3000.

Login (default often admin/admin).

Data source:

Go to “Connections → Data sources”.

Confirm there is a Prometheus source pointing at http://prometheus:9090. It should be already provisioned from grafana-datasource.yml.

Dashboards:

Under “Dashboards”, you should see something like myapp-observability loaded from myapp-observability.json.

Open it; panels should show data after a minute or so of traffic.

If you’ve added the panels described in section 3:

Requests per second (RPS) should show spikes when you run make hit-api-multiple.

Top 5 RPS by path should list /docs, /metrics, /api/v1/... etc.

HTTP latency P90 should show a small, stable latency line.

8. How to add Grafana panels (for myapp)
If you rebuild or extend your dashboard JSON (myapp-observability.json), here are concrete panels that match your metrics style (method/path/status/env labels).

Assume your metrics are:

http_requests_total{method, path, status, env}

http_request_duration_seconds_bucket{method, path, env, le}

Panel 1: Requests per second (overall)
Type: Time series

Title: Requests per second (RPS)

Query (PromQL):

text
sum by (env) (
  rate(http_requests_total[1m])
)
This shows total RPS per environment (dev/staging/prod).

Panel 2: Requests per second by route
Type: Time series

Title: Top 5 RPS by path

Query:

text
topk(
  5,
  sum by (path) (
    rate(http_requests_total[1m])
  )
)
Shows the busiest endpoints. If you prefer to include method:

text
topk(
  5,
  sum by (method, path) (
    rate(http_requests_total[1m])
  )
)
Panel 3: Error rate (5xx)
Type: Time series

Title: 5xx error rate

Query:

text
sum by (env) (
  rate(http_requests_total{status=~"5.."}[5m])
)
Optional variant (percentage of all):

text
100 *
sum(rate(http_requests_total{status=~"5.."}[5m])) /
sum(rate(http_requests_total[5m]))
Panel 4: Latency P90 (overall)
Using your histogram http_request_duration_seconds:

Type: Time series

Title: HTTP latency P90

Query:

text
histogram_quantile(
  0.9,
  sum by (le) (
    rate(http_request_duration_seconds_bucket[5m])
  )
)
You can duplicate this panel for P50 and P99 (change 0.9 to 0.5/0.99).

Panel 5: Latency P90 by route (top)
Type: Time series

Title: P90 latency by path (top 5)

Query:

text
topk(
  5,
  histogram_quantile(
    0.9,
    sum by (le, path) (
      rate(http_request_duration_seconds_bucket[5m])
    )
  )
)
This shows the slowest endpoints by 90th percentile latency.

Panel 6: Traffic split by status code
Type: Bar chart or time series

Title: Requests by status code

Query:

text
sum by (status) (
  rate(http_requests_total[5m])
)
Gives you a quick view of 2xx/4xx/5xx distribution.

You can bake all these panels into myapp-observability.json once, then reuse that dashboard JSON across services by adjusting the job/env labels if needed.

Note: Details about metrics_middleware:
metrics_middleware(app_env: str) is a factory that returns a FastAPI middleware function. We call it “middleware” because FastAPI runs that returned function around every request, before and after your route handler.

What it is
In your code (simplified idea):

python
def metrics_middleware(app_env: str):
    async def middleware(request: Request, call_next):
        # before route handler
        response = await call_next(request)
        # after route handler
        return response
    return middleware
metrics_middleware(app_env) is not the middleware itself.

It returns middleware, which is the actual callable FastAPI uses.

You register it with:

python
app.middleware("http")(metrics_middleware(app_env))
So FastAPI sees the inner middleware(request, call_next) as the HTTP middleware.

Why it’s called middleware
Because the returned middleware function fits FastAPI’s middleware contract:

It takes request and call_next.

It runs before your endpoint handler, can do something (start timer, update metrics), calls response = await call_next(request), then runs after the handler (record status, observe latency) and returns response.

That “wrap every request, run logic before and after” behavior is exactly what FastAPI defines as middleware, so metrics_middleware(...) is a middleware factory, and the function it returns is the actual middleware.