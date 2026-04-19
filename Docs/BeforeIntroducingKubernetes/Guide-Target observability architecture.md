1) Target observability architecture
For your monorepo, a solid, future‑proof setup looks like:

Logs

    Structured JSON logs for myapp (FastAPI) and mylearning.

    Per‑request correlation ID and basic request context in every log line.

Metrics + dashboards

    HTTP metrics (request count, error count, latency buckets) exported in Prometheus format at /metrics.

    Docker‑Compose‑managed Prometheus + Grafana stack to scrape metrics and show dashboards.

Traces (OpenTelemetry)

    FastAPI auto‑instrumentation with OpenTelemetry.

    Spans per request, DB calls, and key operations.

    Export via OTLP (so you can later point it to Jaeger, Tempo, Honeycomb, etc.).

All of this should be controllable by env vars (dev vs staging vs prod) so you can run the same code and compose files in all environments.

2. Use JSON logging in all environments except local dev.
Here, “In all environments except local dev” means the log format should switch based on environment, usually controlled by an environment variable such as ENV=local, ENV=dev, ENV=staging, or ENV=prod

3. OpenTelemetry tracing
    OpenTelemetry tracing is a standard way to follow a request as it moves through your application or across multiple services, so you can see where time is spent and where errors happen. It represents that journey as a trace made up of spans, where each span is one unit of work such as an HTTP call, database query, or background job.

    Core idea
        - A trace is the full path of one request or transaction through a system.

        - A span is a single step inside that path, with timing and metadata.

        - Spans are linked together using context propagation so you can reconstruct the whole flow across services.

    Why it matters
        Tracing helps you debug slow requests, find bottlenecks, and understand failures in distributed systems. It is especially useful in microservices, where one user action may touch several services before finishing.

    Simple example
        If a user submits a checkout form, OpenTelemetry tracing can show spans for authentication, inventory lookup, payment processing, and database writes, all stitched into one trace. That gives you a timeline of the request instead of isolated logs from each service.

    OpenTelemetry role
        OpenTelemetry is the open, vendor-neutral observability framework that generates, collects, and exports telemetry such as traces, metrics, and logs. It is not itself a monitoring backend; it sends data to tools like Jaeger or other observability platforms.

4. Prometheus Setup:
You do need a small amount of Prometheus setup, but most of it is just:

    - adding the Prometheus container to Docker Compose
    - giving it a config file that tells it to scrape myapp:8000/metrics.

After that, Grafana only needs to be pointed at Prometheus.

    1) Prometheus setup you need

    a) Prometheus config file
        Create Docker/prometheus.yml in your repo:
            global:
            scrape_interval: 15s

            scrape_configs:
            - job_name: "myapp"
                metrics_path: /metrics
                static_configs:
                - targets:
                    - "myapp:8000"
        - myapp here is the Docker service name from your compose file.
        - Prometheus will hit http://myapp:8000/metrics every 15s.

        If you later add more services or exporters, you just add more scrape_configs blocks.

        b) Add Prometheus service to docker-compose.base.yml
        Extend your docker-compose.base.yml:
            services:
            db:
                # ... existing db config ...

            myapp:
                # ... existing myapp config, must expose port 8000 internally ...

            mylearning:
                # ... existing config ...

            prometheus:
                image: prom/prometheus:v2.55.0
                container_name: prometheus
                volumes:
                - ./Docker/prometheus.yml:/etc/prometheus/prometheus.yml:ro
                ports:
                - "9090:9090"
                restart: unless-stopped
    That is all Prometheus “installation” you need:

        - Compose runs Prometheus as another container on the same network.

        - Prometheus reads /etc/prometheus/prometheus.yml, which you mounted from ./Docker/prometheus.yml.

        - It starts scraping myapp automatically.

    You can verify by opening http://localhost:9090 and checking “Status → Targets”.

    2) Grafana setup (minimal)
        In docker-compose.base.yml, you likely already have (or should add):
        grafana:
            image: grafana/grafana:latest
            container_name: grafana
            environment:
            - GF_SECURITY_ADMIN_USER=admin
            - GF_SECURITY_ADMIN_PASSWORD=admin
            ports:
            - "3000:3000"
            restart: unless-stopped
    Then:
        Bring the stack up (dev/staging/prod) with base + override:

    bash
    docker compose -f docker-compose.base.yml -f docker-compose.dev.yml up -d
        1. Open Grafana at http://localhost:3000 (user admin / admin).

        2. Add Prometheus as a data source:
        - URL: http://prometheus:9090
        - Leave auth off (they’re on same Docker network).

        3. Create the dashboard and panels using the PromQL queries I gave you.

    No extra Prometheus coding changes are required beyond:
        - Exposing /metrics in myapp,
        - Adding Prometheus config + service in Compose.
5. Configure Grafana (Dashboard):
You can start with a single Grafana dashboard with 4–5 panels that answer: “Is my API healthy, fast, and error‑free, and is the DB OK?”. Below is a concrete layout with PromQL queries you can paste.

I’ll assume you’re using the REQUEST_COUNT and REQUEST_LATENCY metrics we defined (http_requests_total, http_request_duration_seconds_bucket) with labels method, path, status_code, app_env.

Panel 1: Request rate (RPS)
    Goal: See traffic over time, per endpoint or overall.

    Type: Time series

    Title: Requests per second (RPS)

    Query (overall RPS):

    text
    sum(rate(http_requests_total[$__rate_interval]))
    Query (by path, optional split):

    text
    sum(rate(http_requests_total[$__rate_interval])) by (path)
    Y‑axis: req/s

    This shows spikes in traffic or drops to zero (service down).

Panel 2: Error rate (% of 5xx)
    Goal: Spot when failures spike.

    Type: Time series

    Title: Error rate (5xx %)

    Query:

    text
    100 *
    sum(rate(http_requests_total{status_code=~"5.."}[$__rate_interval]))
    /
    sum(rate(http_requests_total[$__rate_interval]))
    Y‑axis: percent (0–100)

    You can add a threshold line at, say, 1–5%.

Panel 3: P95 latency by endpoint
    Goal: See slow endpoints via latency percentiles.

    Your histogram is http_request_duration_seconds_bucket. To compute p95:

    Type: Time series

    Title: P95 latency by endpoint

    Query:

    text
    histogram_quantile(
    0.95,
    sum(rate(http_request_duration_seconds_bucket[$__rate_interval]))
        by (path, le)
    )
    Y‑axis: seconds

    Legend: {{path}}

    You can also duplicate this panel for p50, p90, p99 by changing 0.95 to 0.5 / 0.9 / 0.99.

Panel 4: Latency SLO check (single value / gauge)
    Goal: Quick “are we within SLO?” view, e.g. “P95 < 0.25s”.

    Type: Stat or Gauge

    Title: Current P95 latency (all endpoints)

    Query:

    text
    histogram_quantile(
    0.95,
    sum(rate(http_request_duration_seconds_bucket[$__rate_interval]))
        by (le)
    )
    Y‑axis: seconds

    Thresholds:

    Green: 0 – 0.25

    Yellow: 0.25 – 0.5

    Red: > 0.5

    This uses all paths together; you can scope it to a particular critical API path with `{path="/api/v1/..."} if needed.

Panel 5: DB health (basic)
    Initially, you may not have a Postgres exporter yet. Two minimal options:

    From your app metrics (easiest): count DB errors. If you add a counter db_errors_total in FastAPI whenever a DB call fails, you can show:

    Type: Time series

    Title: DB errors per second

    Query:

    text
    sum(rate(db_errors_total[$__rate_interval]))
    With postgres_exporter later:

    If/when you add postgres_exporter, you can use typical queries like:

    Connections:

    text
    sum(pg_stat_activity_count)
    Cache hit ratio:

    text
    avg(rate(pg_stat_database_blks_hit[$__rate_interval]))
    /
    (
    avg(rate(pg_stat_database_blks_hit[$__rate_interval]))
    + avg(rate(pg_stat_database_blks_read[$__rate_interval]))
    )
    For now, start with app‑side DB error count until you integrate a proper exporter.

Panel 6 (optional): Top endpoints by traffic
    Goal: See which endpoints get most load.

    Type: Table or Bar chart

    Title: Top endpoints by RPS

    Query:

    text
    topk(
    10,
    sum(rate(http_requests_total[$__rate_interval])) by (path)
    )
    Show columns for path and value (RPS).

How to implement in Grafana
    - In Grafana, create a new dashboard.
    - Add panels one by one, choosing Prometheus as the datasource.
    - Paste the PromQL queries above into each panel’s query editor.
    - Use $__rate_interval in queries (default variable Grafana sets based on time range).
    - Save the dashboard as something like myapp-observability.

This layout gives you an enterprise‑style “NOC view”:

    Panel 1: Traffic
    Panel 2: Error rate
    Panel 3–4: Latency distribution + SLO
    Panel 5: Basic DB health
    Panel 6: Top endpoints
