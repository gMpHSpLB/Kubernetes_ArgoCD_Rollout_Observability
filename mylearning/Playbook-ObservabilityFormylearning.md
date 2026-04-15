playbook for how observability (logs, metrics, traces) is wired for mylearning in the monorepo‑root setup.

1. Monorepo structure and Docker build
Monorepo root contains myapp/, mylearning/, Docker/, and the compose files.

Docker builds use monorepo root as build context:

context: .

dockerfile: mylearning/Dockerfile or myapp/Dockerfile.

myapp Dockerfile (key observability parts)
Working dir and dependency installation:

text
FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 POETRY_VIRTUALENVS_CREATE=false
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*

# pyproject + lock from myapp
COPY myapp/pyproject.toml ./pyproject.toml
COPY myapp/poetry.lock ./poetry.lock

# path dependency target (../mylearning)
COPY mylearning /mylearning

RUN pip install --no-cache-dir poetry && \
    poetry install --only main --no-interaction --no-ansi && \
    if [ "$INSTALL_DEV" = "true" ]; then \
      poetry install --with dev --no-interaction --no-ansi; \
    fi

COPY myapp/src ./src
COPY myapp/tests ./tests
ENV PYTHONPATH=/app/src

CMD ["poetry","run","uvicorn","myapp.main:app","--host","0.0.0.0","--port","8000","--proxy-headers","--forwarded-allow-ips","*"]
COPY mylearning /mylearning plus mylearning = { path = "../mylearning", ... } in myapp/pyproject.toml makes exercises importable inside the container.

mylearning/Dockerfile follows the same pattern (Poetry, src/tests copied, APP_ENV=ci, etc.).

2. Path dependency wiring (myapp → mylearning)
myapp/pyproject.toml
Add mylearning as a path dependency relative to myapp on host:

text
[tool.poetry.dependencies]
# ... myapp deps ...
mylearning = { path = "../mylearning", develop = true }
This works:

On host: myapp and mylearning are siblings under the repo root.

In images: pyproject.toml is at /app/pyproject.toml, ../mylearning resolves to /mylearning (we copied it in the Dockerfile).

mylearning/pyproject.toml
Add OpenTelemetry deps because exercises.tracing imports them:

text
[tool.poetry.dependencies]
python = "^3.11"
# ...existing...
opentelemetry-api = ">=1.25.0"
opentelemetry-sdk = ">=1.25.0"
opentelemetry-exporter-otlp = ">=1.25.0"
opentelemetry-instrumentation-logging = ">=0.46b0"
Run poetry lock in both myapp and mylearning after these changes and commit the updated lock files.

3. CI‑only compose: running tests with monorepo root
docker-compose.yml is for CI and test only (not deploy).

Key configuration for myapp and mylearning:

text
services:
  db:
    image: postgres:15
    # env + healthcheck...

  myapp:
    build:
      context: .
      dockerfile: myapp/Dockerfile
      args:
        INSTALL_DEV: "true"
    image: myapp
    container_name: myapp-container
    working_dir: /app/myapp
    volumes:
      - .:/app        # mount monorepo root
    depends_on:
      - db
    environment:
      APP_ENV: ci
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: mydb
      DB_USER: myuser
      DB_PASSWORD: mypassword
    ports:
      - "8000:8000"

  mylearning:
    build:
      context: .
      dockerfile: mylearning/Dockerfile
      args:
        INSTALL_DEV: "true"
    image: mylearning
    container_name: mylearning-container
    working_dir: /app/mylearning
    volumes:
      - .:/app        # mount monorepo root
    environment:
      APP_ENV: ci
    ports:
      - "8001:8000"
Why:

Mounting . at /app and using those working_dirs makes the layout inside test containers match the host (so ../mylearning path dependency remains valid).

Tests run via docker compose run myapp ... / docker compose run mylearning ... in make test-docker.

docker-compose.base.yml + docker-compose.*.yml for dev/staging/prod remain “runtime only” (no code volumes, just image: ${IMAGE_*}), so images are immutable there.

4. Logs, metrics, and traces in mylearning
Logs
APP_ENV is set (e.g., ci, dev, staging, prod) and used by the logging config; JSON logging uses python-json-logger as per your dependencies.

In CI, logs from both myapp and mylearning go to stdout and are captured by docker compose run and GitHub Actions.

Metrics
myapp exposes Prometheus metrics via the metrics middleware and endpoint in src/myapp/metrics.py and src/myapp/main.py.

Prometheus and Grafana are configured in docker-compose.base.yml with:

Prometheus scraping http://myapp:8000/metrics.

Grafana provisioned with grafana-datasource.yml and grafana-dashboards.yml and Docker/dashboards/myapp-observability.json.

When myapp calls exercises.fibonacci from mylearning, those calls run in the same process, so metrics attached to HTTP requests still show the combined behavior on the dashboard.

Traces (myapp + mylearning)
src/myapp/main.py sets up OpenTelemetry tracing:

Reads OTEL_ENABLED, UPTRACE_DSN, UPTRACE_TOKEN, OTEL_SERVICE_NAME, etc.

Configures TracerProvider + OTLPSpanExporter to Uptrace (api.uptrace.dev).

Uses FastAPIInstrumentor.instrument_app with a server_request_hook for extra attributes.

mylearning uses exercises/tracing.py to create a tracer via opentelemetry.trace. Its spans go to the same collector when OTEL_ENABLED and env vars are set, because they share the global tracer provider configured in myapp.

This gives you:

End‑to‑end traces where myapp HTTP spans contain child spans from mylearning calls.

Centralized views in Uptrace (or any OTLP backend) for both services.

5. Operational commands (how to use this)
Build dev images (with dev deps) via CI/locally:

bash
make docker-build          # uses docker compose build with monorepo context
Run Dockerized tests in parallel (myapp + mylearning):

bash
make test-docker           # brings up db, then docker compose run myapp/mylearning pytest
Bring up dev/staging/prod stack with observability:

bash
# dev example
IMAGE_MYAPP=... IMAGE_MYLEARNING=... APP_ENV=dev \
DB_* ... OTEL_* ... \
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml up -d
Prometheus on localhost:9090, Grafana on localhost:3000, myapp on localhost:8000.

Inspect traces in Uptrace using the configured DSN/env variables.

This playbook is the “final state” of what you wired: monorepo‑root builds, path dependency from myapp to mylearning, shared observability stack (logs, Prometheus+Grafana, OpenTelemetry traces) working across both projects.

___________________________________________________________
Below is a minimal, practical set of changes.

1. Structured logging for mylearning
Goal: whenever exercises code logs, it uses the same style as myapp (JSON in prod, plain in dev).

1.1 Add a simple logging config module
Create mylearning/src/exercises/logging_config.py:

python
# mylearning/src/exercises/logging_config.py
import logging
import os
import sys
from pythonjsonlogger import jsonlogger


def setup_logging() -> None:
    logger = logging.getLogger()
    logger.handlers.clear()

    log_level = os.getenv("LOG_LEVEL", "INFO").upper()
    env = os.getenv("APP_ENV", "dev").lower()

    handler = logging.StreamHandler(sys.stdout)

    if env == "dev":
        formatter = logging.Formatter(
            fmt="%(asctime)s %(levelname)s [%(name)s] %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
    else:
        formatter = jsonlogger.JsonFormatter(
            fmt="%(asctime)s %(levelname)s %(name)s %(message)s",
            rename_fields={"asctime": "timestamp", "levelname": "level"},
            datefmt="%Y-%m-%dT%H:%M:%SZ",
        )

    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(log_level)
You don’t need per‑request correlation IDs here because mylearning is called by tests or by myapp; correlation is handled at the service boundary. Logging docs: structured logging via python-json-logger is idiomatic.

1.2 Use logging in fibonacci.py
In mylearning/src/exercises/fibonacci.py:

python
# mylearning/src/exercises/fibonacci.py
import logging

logger = logging.getLogger(__name__)


def fib(n: int) -> int:
    if n < 0:
        logger.warning("fib called with negative input", extra={"n": n})
        raise ValueError("n must be non-negative")

    logger.info("fib_start", extra={"n": n})
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    logger.info("fib_end", extra={"n": n, "result": a})
    return a
In your tests (or when using mylearning directly), call setup_logging() once at process start:

python
from exercises.logging_config import setup_logging

setup_logging()
Now logs from exercises will be structured like myapp’s logs (adjusted to “library” context).

2. Metrics for mylearning (library‑focused)
Because mylearning is not an HTTP service, you don’t expose /metrics here. Instead, you can:

Export Prometheus counters for core functions.

If mylearning runs inside myapp, metrics will show up in myapp’s /metrics.

If you run a separate service around mylearning later, you can reuse the same metrics.

2.1 Add metrics module
Create mylearning/src/exercises/metrics.py:

python
# mylearning/src/exercises/metrics.py
from prometheus_client import Counter, Histogram

FIB_CALLS = Counter(
    "mylearning_fib_calls_total",
    "Total calls to fib()",
    ["status"],  # "ok" or "error"
)

FIB_DURATION = Histogram(
    "mylearning_fib_duration_seconds",
    "Time spent inside fib()",
    buckets=(0.0001, 0.001, 0.01, 0.1, 1),
)
2.2 Use metrics in fibonacci.py
python
import logging
import time
from .metrics import FIB_CALLS, FIB_DURATION

logger = logging.getLogger(__name__)


def fib(n: int) -> int:
    start = time.perf_counter()
    try:
        if n < 0:
            FIB_CALLS.labels(status="error").inc()
            logger.warning("fib called with negative input", extra={"n": n})
            raise ValueError("n must be non-negative")

        logger.info("fib_start", extra={"n": n})
        a, b = 0, 1
        for _ in range(n):
            a, b = b, a + b
        logger.info("fib_end", extra={"n": n, "result": a})
        FIB_CALLS.labels(status="ok").inc()
        return a
    finally:
        FIB_DURATION.observe(time.perf_counter() - start)
When mylearning runs within myapp, you can import these metrics in myapp.metrics and include them in the same registry (or rely on the default REGISTRY). Then they will be visible on /metrics under names like mylearning_fib_calls_total. Prometheus docs: this pattern (library metrics exported via shared registry) is standard.

3. Traces (OpenTelemetry) for mylearning
Again, mylearning doesn’t own the service boundary. The pattern is:

Let the service (myapp) set up OTEL.

In mylearning, only use trace.get_tracer and create spans as needed.

3.1 Add tracing support in mylearning
Create mylearning/src/exercises/tracing.py:

python
# mylearning/src/exercises/tracing.py
from opentelemetry import trace

tracer = trace.get_tracer("mylearning")
Update fibonacci.py:

python
from .tracing import tracer

def fib(n: int) -> int:
    with tracer.start_as_current_span("mylearning.fib") as span:
        span.set_attribute("fib.n", n)
        # existing logging + metrics code
        ...
When myapp has OTEL configured, calls into exercises.fib() will show a child span mylearning.fib inside the request trace. OTEL best practice is to let libraries use the global tracer without configuring exporters themselves
_________________________________________________________
How to view logs:
1) Add logging setup in mylearning tests
Create (or edit) mylearning/tests/conftest.py:

python
# mylearning/tests/conftest.py
from exercises.logging_config import setup_logging

def pytest_configure(config) -> None:
    # Configure logging once per worker process
    setup_logging()
This guarantees every pytest worker process for mylearning initializes your logging config. Without this, your logger = logging.getLogger(__name__) in fibonacci.py will log with default handlers, and pytest’s CLI logging may not show it.

2) Ensure fib actually logs
In mylearning/src/exercises/fibonacci.py make sure you really log:

python
# src/exercises/fibonacci.py
import logging

logger = logging.getLogger(__name__)

def fib(n: int) -> int:
    logger.info("fib_start", extra={"n": n})
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    logger.info("fib_end", extra={"n": n, "result": a})
    return a
Your coverage report shows lines 18–19 are not hit, which likely are your logging lines, so tests may not be calling the logging path you expect. Adjust tests to call this fib if needed.

3) Run pytest for mylearning only (without xdist first)
To verify logging works, run single‑process tests first:

bash
cd mylearning
poetry run pytest -vv \
  --log-cli-level=INFO \
  --log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s"
You should now see something like:

text
2026-04-15 01:35:00 INFO [exercises.fibonacci] fib_start
2026-04-15 01:35:00 INFO [exercises.fibonacci] fib_end
If that works, then add -n auto back:

bash
poetry run pytest -vv -n auto \
  --log-cli-level=INFO \
  --log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s"
xdist can interleave output, but logs should still appear.
_____________________________________________________
5. How to view logs from Docker
5.1 Dev environment
When you run dev stack with Docker compose (base + dev):

bash
# build runtime images once
make docker-build

# bring up dev stack
IMAGE_MYAPP=... IMAGE_MYLEARNING=... APP_ENV=dev \
OTEL_ENABLED=true UPTRACE_DSN=... UPTRACE_TOKEN=... \
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml up -d
Check logs:

All services:

bash
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml logs -f
Single service:

bash
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml logs -f myapp
docker compose -f docker-compose.base.yml -f docker-compose.dev.yml logs -f mylearning
Because logging is JSON to stdout, you’ll see structured entries with request fields and (when tracing is enabled) trace/span IDs.

For CI tests (local):

bash
make test-docker               # runs tests in containers
# Then:
docker compose logs myapp
docker compose logs mylearning
Again, logs are stdout from those test containers.

5.2 Staging / prod environment
Assuming you use the same docker-compose.base.yml plus docker-compose.staging.yml/docker-compose.prod.yml on the target host:

Start stack (example staging):

bash
IMAGE_MYAPP=... IMAGE_MYLEARNING=... APP_ENV=staging \
OTEL_ENABLED=true UPTRACE_DSN=... UPTRACE_TOKEN=... \
docker compose -f docker-compose.base.yml -f docker-compose.staging.yml up -d
View logs on the host:

bash
docker compose -f docker-compose.base.yml -f docker-compose.staging.yml logs -f myapp
docker compose -f docker-compose.base.yml -f docker-compose.staging.yml logs -f mylearning
If you later plug into a log collector (e.g., Loki, ELK, CloudWatch), you don’t need code changes: they just ingest these stdout JSON logs.

In all environments:

Metrics: open Grafana (port 3000 in dev; staging/prod host-specific) and use the pre‑provisioned dashboard, or query Prometheus directly.

Traces: open Uptrace (or your OTLP backend), filter by service.name=myapp-<env>, and you’ll see HTTP spans plus child spans coming from mylearning