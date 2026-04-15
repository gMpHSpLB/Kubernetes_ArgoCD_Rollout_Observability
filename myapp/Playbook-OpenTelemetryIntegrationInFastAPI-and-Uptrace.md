Here’s a compact “playbook” you can reuse to add OpenTelemetry tracing to any FastAPI app (like myapp) and send per‑request traces to Uptrace.

1. Install OTEL + FastAPI instrumentation
Add dependencies (Poetry or pip):

bash
poetry add \
  opentelemetry-api \
  opentelemetry-sdk \
  opentelemetry-exporter-otlp \
  opentelemetry-instrumentation-fastapi
These are the standard OTEL SDK, OTLP exporter, and FastAPI auto‑instrumentation packages.

2. Configure tracing for Uptrace
In src/myapp/main.py (or a tracing.py module), set up the tracer provider and exporter.

Environment variables you’ll use:

OTEL_ENABLED – "true" to turn tracing on.

OTEL_SERVICE_NAME – e.g. myapp-dev.

UPTRACE_DSN – your Uptrace DSN, e.g.
https://WLfJDCI9dKwaoXgI-Z-jFg@api.uptrace.dev?grpc=4317.

Code:

python
import os
import grpc
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

def _env_true(name: str, default: str = "false") -> bool:
    return os.getenv(name, default).strip().lower() in {"1", "true", "yes", "on"}


def setup_tracing() -> TracerProvider | None:
    print("OTEL: setup_tracing called")
    if not _env_true("OTEL_ENABLED"):
        print("OTEL: disabled via OTEL_ENABLED")
        return None

    dsn = os.getenv("UPTRACE_DSN")
    if not dsn:
        token = os.getenv("UPTRACE_TOKEN")
        if not token:
            print("OTEL: UPTRACE_DSN/UPTRACE_TOKEN not set")
            return None
        dsn = f"https://{token}@api.uptrace.dev?grpc=4317"

    service_name = os.getenv("OTEL_SERVICE_NAME", "myapp-dev")

    resource = Resource.create(
        {
            "service.name": service_name,
            "service_version": "1.0.0",
            "service.namespace": os.getenv("OTEL_SERVICE_NAMESPACE", "default"),
            "deployment.environment": os.getenv("ENVIRONMENT", "local"),
        }
    )

    provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(provider)

    exporter = OTLPSpanExporter(
        endpoint="https://api.uptrace.dev:4317",
        headers={"uptrace-dsn": dsn},
        timeout=30,
        compression=grpc.Compression.Gzip,
    )

    provider.add_span_processor(BatchSpanProcessor(exporter))
    print("OTEL: tracer provider configured")
    return provider
This matches Uptrace’s “direct OTLP gRPC” config, using https://api.uptrace.dev:4317 plus uptrace-dsn header.

3. Instrument the FastAPI app (global app)
In the same main.py, after you create the FastAPI app, instrument it with FastAPIInstrumentor so you get per‑request spans.

Skeleton of main.py with lifespan and middleware:

python
from contextlib import asynccontextmanager, suppress
from fastapi import FastAPI, HTTPException, Request
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry import trace

from myapp.api.v1.routes import router as v1_router
from myapp.core.config import settings
from myapp.logging_config import logging_middleware, setup_logging
from myapp.metrics import metrics_middleware, metrics_endpoint

# --- shared state for shutdown guard ---

class State:
    shutting_down = False

state = State()

# --- optional: hook to tag all HTTP spans ---

def server_request_hook(span, scope):
    if span and span.is_recording():
        path = scope.get("path", "")
        method = scope.get("method", "")
        print("OTEL: server_request_hook called", method, path)
        span.set_attribute("http.route", path)
        span.set_attribute("http.method", method)

# --- lifespan to init / shutdown tracing ---

@asynccontextmanager
async def lifespan(app: FastAPI):
    provider = setup_tracing()
    yield
    state.shutting_down = True
    if provider is not None:
        with suppress(Exception):
            provider.shutdown()

# --- create FastAPI app and middleware ---

def create_app() -> FastAPI:
    setup_logging()
    app = FastAPI(title=settings.app_name, lifespan=lifespan)

    app_env = os.getenv("APP_ENV", "dev")
    app.middleware("http")(logging_middleware)
    app.middleware("http")(metrics_middleware(app_env))

    app.include_router(v1_router, prefix="/api/v1")
    return app

app = create_app()

# Instrument the global app instance
FastAPIInstrumentor.instrument_app(
    app,
    excluded_urls=os.getenv("OTEL_PYTHON_FASTAPI_EXCLUDED_URLS", "healthz,readyz"),
    server_request_hook=server_request_hook,
)
print("OTEL: FastAPIInstrumentor.instrument_app (global) done")

# --- extra endpoints (metrics/health/debug) ---

@app.get("/metrics")
async def metrics():
    return await metrics_endpoint()

@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok", "env": settings.app_env}

@app.middleware("http")
async def reject_requests_during_shutdown(request: Request, call_next):
    if state.shutting_down and request.url.path not in {"/healthz", "/readyz"}:
        raise HTTPException(status_code=503, detail="Shutting down")
    return await call_next(request)

@app.get("/healthz")
async def healthz():
    return {"status": "ok"}

@app.get("/readyz")
async def readyz():
    if state.shutting_down:
        raise HTTPException(status_code=503, detail="not ready")
    return {"status": "ready"}

@app.get("/debug-trace")
async def debug_trace():
    tracer = trace.get_tracer("myapp.debug")
    with tracer.start_as_current_span("debug-span") as span:
        span.set_attribute("debug", True)
        return {"status": "ok"}
Key points:

setup_tracing() configures the provider + exporter (called in lifespan).

FastAPIInstrumentor.instrument_app(app, ...) is called once on the global app after create_app(). This is what finally made hooks run and per‑request spans appear.

server_request_hook annotates every HTTP span with route/method, making debugging and querying easier.

4. Environment variables for dev
For a dev run pointing to Uptrace, set:

bash
export OTEL_ENABLED=true
export OTEL_SERVICE_NAME=myapp-dev
export UPTRACE_DSN="https://<your-token>@api.uptrace.dev?grpc=4317"
export OTEL_TRACES_SAMPLER=always_on
Then your dev-up Make target can pass these into Docker, e.g.:

text
dev-up: docker-build
	APP_ENV=dev \
	OTEL_ENABLED=true \
	OTEL_SERVICE_NAME=myapp-dev \
	UPTRACE_DSN="https://WLfJDCI9dKwaoXgI-Z-jFg@api.uptrace.dev?grpc=4317" \
	OTEL_TRACES_SAMPLER=always_on \
	docker compose -f docker-compose.base.yml -f docker-compose.dev.yml up -d
This aligns with OTEL’s env‑based configuration and Uptrace’s OTLP setup.

5. How to verify traces end‑to‑end
Start dev stack:

bash
make dev-up
Generate traffic:

bash
for i in {1..20}; do
  curl -s -o /dev/null http://localhost:8000/docs
  curl -s -o /dev/null http://localhost:8000/metrics
  curl -s -o /dev/null http://localhost:8000/api/v1/users || true  # use a real route
done

curl -s -o /dev/null http://localhost:8000/debug-trace
In Uptrace (correct project, “Last 30 minutes”):

Use queries like:

text
where service_name = "myapp-dev"
Then:

text
where service_name = "myapp-dev" and display_name contains "HTTP GET"
And specific routes:

text
where service_name = "myapp-dev" and display_name = "HTTP GET /metrics"
You should see:

debug-span from /debug-trace.

HTTP GET /docs, HTTP GET /metrics, HTTP GET /api/v1/... from normal requests.

6. Minimal checklist for future projects
When you want to repeat this in another FastAPI service:

Install OTEL SDK + FastAPI instrumentation.

Implement setup_tracing():

Set TracerProvider with service.name.

Configure OTLPSpanExporter to https://api.uptrace.dev:4317 with uptrace-dsn.

Use a lifespan or startup hook to call setup_tracing().

After app = FastAPI(...) / app = create_app(), call:

python
FastAPIInstrumentor.instrument_app(app, server_request_hook=server_request_hook)
Set OTEL_ENABLED=true, OTEL_SERVICE_NAME=..., UPTRACE_DSN=..., OTEL_TRACES_SAMPLER=always_on.

Hit /docs, /metrics, and some /api/... routes; query in Uptrace by service_name and display_name.

Note:
“FastAPI auto‑instrumentation” means OpenTelemetry attaches itself to your FastAPI app and generates spans for each request without you adding tracing code to every route.

More concretely:

The opentelemetry-instrumentation-fastapi package provides a FastAPIInstrumentor that knows how FastAPI handles requests.

When you call FastAPIInstrumentor.instrument_app(app), it wraps the app so that every incoming HTTP request automatically creates a span like HTTP GET /api/v1/users, with standard attributes (status code, method, path, etc.).

You don’t have to write tracer = trace.get_tracer(...); with tracer.start_as_current_span(...) in each route; that part is handled for you by the instrumentation library.

It’s called auto‑instrumentation (or “zero‑code instrumentation”) because:

The tracing logic is implemented in a reusable library/agent that hooks into FastAPI’s internals (ASGI call stack, request/response cycle).

Once enabled (via FastAPIInstrumentor.instrument_app(app) or via the opentelemetry-instrument CLI for full zero‑code), you get telemetry for all routes with minimal to no changes to your business code.

In contrast, manual instrumentation is when you explicitly create spans in your code:

python
tracer = trace.get_tracer("myapp")
with tracer.start_as_current_span("custom-operation"):
    ...  # your code
You still do manual instrumentation for extra detail (e.g., DB calls, specific business steps), but the per‑request spans are handled automatically by the FastAPI instrumentation, which is why we call it “FastAPI auto‑instrumentation.”
