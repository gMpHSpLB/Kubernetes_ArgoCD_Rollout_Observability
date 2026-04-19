# Main App : FastAPI-style entrypoint
# src/myapp/main.py
import os
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager, suppress
from typing import Any, Dict, Mapping

import grpc
from fastapi import FastAPI, HTTPException, Request, Response
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from myapp.api.v1.routes import router as v1_router
from myapp.core.config import settings
from myapp.logging_config import logging_middleware, setup_logging
from myapp.metrics import metrics_endpoint, metrics_middleware

DISABLE_CUSTOM_MIDDLEWARE = os.getenv("DISABLE_CUSTOM_MIDDLEWARE", "false").lower() in {
    "1",
    "true",
    "yes",
    "on",
}

"""
This code defines a FastAPI app that can optionally export
OpenTelemetry traces, and it also adds a graceful shutdown
guard so normal requests are rejected while the app is stopping.
It exposes two lightweight endpoints, /healthz and /readyz,
for health/readiness checks. FastAPI is a Python web framework
for building APIs, and middleware is a layer that runs for each
request before the route handler executes.

What the code is for
The app has two main responsibilities:

    - Observability: send tracing data to an OpenTelemetry collector when enabled.
    - Shutdown safety: stop serving regular traffic during shutdown, while still allowing health checks.

This pattern is common in containerized deployments, where
orchestration systems need reliable readiness and health
endpoints to decide whether a service should receive traffic.
"""

"""
This helper reads an environment variable and interprets
common “true” values. It treats "1", "true", "yes", and "on"
as enabled. If the variable is missing, it uses the provided default.

So _env_true("OTEL_ENABLED") is basically a convenient way to
ask, “Is tracing turned on?”
"""


def _env_true(name: str, default: str = "false") -> bool:
    return os.getenv(name, default).strip().lower() in {"1", "true", "yes", "on"}


# server_request_hook should print on every request
def server_request_hook(span: Any, scope: Mapping[str, Any]) -> None:
    if span and span.is_recording():
        path = scope.get("path", "")
        print("OTEL: server_request_hook called", path)
        span.set_attribute("app.component", "myapp-api")


"""
This creates a simple shared state holder with one flag:
shutting_down. The app sets this flag to True when shutdown
starts. The middleware later checks this flag to decide
whether to reject requests.

A single global state object is used so the lifespan
handler and middleware can communicate.
"""


class State:
    shutting_down = False


state = State()


# This function configures OpenTelemetry tracing,
# but only if OTEL_ENABLED is true.
# So this function is the observability bootstrap for the app.
# setup_tracing() sets the global tracer provider and exporter.
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


# def setup_tracing(app: FastAPI) -> TracerProvider | None:
#     print("OTEL: setup_tracing called")
#     if not _env_true("OTEL_ENABLED"):
#         print("OTEL: disabled via OTEL_ENABLED")
#         return None

#     dsn = os.getenv("UPTRACE_DSN")
#     if not dsn:
#         token = os.getenv("UPTRACE_TOKEN")
#         if not token:
#             print("OTEL: UPTRACE_DSN/UPTRACE_TOKEN not set")
#             return None
#         # Build DSN exactly as Uptrace expects
#         dsn = f"https://{token}@api.uptrace.dev?grpc=4317"

#     service_name = os.getenv("OTEL_SERVICE_NAME", "myapp-dev")

#     resource = Resource.create(
#         {
#             "service.name": service_name,
#             "service_version": "1.0.0",
#             "service.namespace": os.getenv("OTEL_SERVICE_NAMESPACE", "default"),
#             "deployment.environment": os.getenv("ENVIRONMENT", "local"),
#         }
#     )

#     provider = TracerProvider(resource=resource)
#     trace.set_tracer_provider(provider)

#     # Uptrace gRPC exporter (TLS; no `insecure=True`)
#     exporter = OTLPSpanExporter(
#         endpoint="https://api.uptrace.dev:4317",
#         headers={"uptrace-dsn": dsn},
#         timeout=30,
#         compression=grpc.Compression.Gzip,
#     )

#     provider.add_span_processor(BatchSpanProcessor(exporter))

#     FastAPIInstrumentor.instrument_app(
#         app,
#         excluded_urls=os.getenv("OTEL_PYTHON_FASTAPI_EXCLUDED_URLS", "healthz,readyz"),
#         server_request_hook=server_request_hook
#     )

#     print("OTEL: FastAPIInstrumentor.instrument_app done")
#     return provider


# def setup_tracing(app: FastAPI) -> TracerProvider | None:
#     print("OTEL: setup_tracing called")  # TEMP debug
#     if not _env_true("OTEL_ENABLED"):
#         print("OTEL: disabled via OTEL_ENABLED")
#         return None

#     """
#     It reads tracing configuration from environment variables:

#         - OTEL_SERVICE_NAME defaults to myapp
#         - OTEL_EXPORTER_OTLP_ENDPOINT defaults to api.uptrace.dev:4317
#         - OTEL_EXPORTER_OTLP_INSECURE defaults to false
#     """
#     service_name = os.getenv("OTEL_SERVICE_NAME", "myapp")
#     otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "api.uptrace.dev:4317")
#     uptrace_token = os.getenv("UPTRACE_TOKEN")
#     insecure = _env_true("OTEL_EXPORTER_OTLP_INSECURE", "false")

#     if not otlp_endpoint or not uptrace_token:
#         print("OTEL: ENDPOINT or UPTRACE_TOKEN is not set")
#         # fail fast or just return; for now, silently skip
#         return None

#     print(f"OTEL: using endpoint={otlp_endpoint}, service_name={service_name}, uptrace_token={uptrace_token}")
#     """
#     It creates a Resource with service metadata:

#         - service.name
#         - service.namespace
#         - deployment.environment
#     """

#     resource = Resource.create(
#         {
#             "service.name": service_name,
#              "service_version": "1.0.0",
#             "service.namespace": os.getenv("OTEL_SERVICE_NAMESPACE", "default"),
#             "deployment.environment": os.getenv("ENVIRONMENT", "local"),
#         }
#     )

#     #It creates a TracerProvider and installs it as the global tracer provider.
#     provider = TracerProvider(resource=resource)
#     trace.set_tracer_provider(provider)

#     """
#     It creates an OTLPSpanExporter and a BatchSpanProcessor.
#         - The exporter sends spans to an OTLP collector.
#         - The batch processor buffers spans and sends them in batches for efficiency.
#     """
#     endpoint1=f"https://{otlp_endpoint}"
#     uptracedsn1 = f"https://{uptrace_token}@api.uptrace.dev?grpc=4317"

#     print(f"OTEL: using endpoint={endpoint1}, uptrace-dsn={uptracedsn1}")
#     exporter = OTLPSpanExporter(endpoint=f"https://{otlp_endpoint}",
#                                 headers={"uptrace-dsn": f"https://{uptrace_token}@api.uptrace.dev?grpc=4317"},
#                                 timeout=30,
#                                 compression=grpc.Compression.Gzip,
#                                 insecure=insecure)
#     processor = BatchSpanProcessor(exporter)
#     provider.add_span_processor(processor)

#     """
#     It instruments the FastAPI app:
#         - FastAPIInstrumentor.instrument_app(...) automatically creates spans for incoming FastAPI requests.
#         - It excludes URLs listed in OTEL_PYTHON_FASTAPI_EXCLUDED_URLS, defaulting to healthz,readyz.
#     """
#     FastAPIInstrumentor.instrument_app(
#         app,
#         excluded_urls=os.getenv("OTEL_PYTHON_FASTAPI_EXCLUDED_URLS", "healthz,readyz"),
#     )

#     """
#     Return value
#         - If tracing is enabled: returns the configured TracerProvider
#         - If tracing is disabled: returns None
#     """
#     print("OTEL: FastAPIInstrumentor.instrument_app done")
#     return provider

"""
FastAPI supports a lifespan function for startup
and shutdown logic.
In short: this gives the app a clean startup/shutdown lifecycle.
Python : lifespan functions are async context managers yielding nothing,
        so AsyncIterator[None] is appropriate.
"""


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # Before yield, it configures tracing if enabled.
    # provider = setup_tracing(app)
    provider = setup_tracing()
    yield

    """
    After the app starts shutting down:
        - It marks the application as shutting down.
        - If tracing was enabled, it shuts down the tracer provider.
        - suppress(Exception) prevents shutdown errors from crashing cleanup.
    """
    state.shutting_down = True
    if provider is not None:
        with suppress(Exception):
            provider.shutdown()


"""
What this does
    setup_logging() runs once when the app starts, so the root logger and formatter are configured before any requests are handled.

    app.middleware("http")(logging_middleware) registers your request logging function as FastAPI middleware, which is the standard way to run logic before and after each request.

    Every request now gets a correlation ID, start/end logs, and an x-request-id response header.
"""


def create_app() -> FastAPI:
    # Logging setup should happen before the app starts
    # serving traffic so all logs, including Uvicorn and app logs, follow the same configuration
    setup_logging()

    """
    This creates the FastAPI app and attaches the lifespan
    handler.
    Because the lifespan handler is used, the app gets custom
    startup and shutdown behavior instead of only route definitions.
    """
    app = FastAPI(title=settings.app_name, lifespan=lifespan)
    app_env = os.getenv("APP_ENV", "dev")
    # FastAPI middleware must be attached to the app object
    # for it to execute on requests.
    if not DISABLE_CUSTOM_MIDDLEWARE:  # Only enable these when debugging is off
        print("OTEL: DISABLE_CUSTOM_MIDDLEWARE enter")
        app.middleware("http")(logging_middleware)
        app.middleware("http")(metrics_middleware(app_env))

    app.include_router(v1_router, prefix="/api/v1")
    return app


app = create_app()

# Instrument the global app so hooks see real traffic
# FastAPIInstrumentor.instrument_app(app, server_request_hook=...) wraps the same app instance Uvicorn uses.
# /healthz (liveness) and /readyz (readiness) excluded from tracing, which matches common recommendations for Kubernetes probes.
FastAPIInstrumentor.instrument_app(
    app,
    excluded_urls=os.getenv("OTEL_PYTHON_FASTAPI_EXCLUDED_URLS", "healthz,readyz"), # This is exactly what OTEL best-practice articles recommend: exclude health endpoints from tracing to avoid huge amounts of low-value spans.
    server_request_hook=server_request_hook,
)
print("OTEL: FastAPIInstrumentor.instrument_app (global) done")


# /metrics exposes the updated values for Prometheus to scrape
# Python: metrics_endpoint already returns a Response; if you want,
#         you can use -> Response instead of Any.
@app.get("/metrics")
async def metrics() -> Any:
    return await metrics_endpoint()


@app.get("/health", tags=["health"])
def health() -> Dict[str, Any]:
    return {"status": "ok", "env": settings.app_env}


"""
This middleware runs for every HTTP request.

Behavior
    - If the app is shutting down and the request is not /healthz or /readyz, it returns a 503 Service Unavailable.
    - Otherwise, it forwards the request to the next handler.

Why this matters
    This prevents new normal traffic from being processed during shutdown.
    That reduces the chance of partially handled requests or inconsistent
    behavior while the process is stopping. Health endpoints are exempt
    so orchestration systems can still check the pod/container status.
"""
if not DISABLE_CUSTOM_MIDDLEWARE:

    @app.middleware("http")
    async def reject_requests_during_shutdown(
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        if state.shutting_down and request.url.path not in {"/healthz", "/readyz"}:
            raise HTTPException(status_code=503, detail="Shutting down")
        return await call_next(request)

# /healthz and /readyz are just normal HTTP routes; Prometheus doesn’t scrape them. 
# It only scrapes /metrics.
"""
Note:
For Kubernetes, the key goal is to expose separate endpoints 
for liveness /healthz and readiness /readzy so Minikube and later your real 
clusters can manage restarts and traffic safely.
"""
"""
This is a basic liveness endpoint. It always returns success and is intended
to answer: “Is the application process alive?”
"""
@app.get("/healthz", tags=["health"])
async def healthz() -> Dict[str, str]:
    return {"status": "ok"}

"""
This is a readiness endpoint. It answers: “Is the application ready to receive traffic?”
    - If the app is shutting down, it returns 503.
    - Otherwise, it returns {"status": "ready"}.
This is useful in Kubernetes-style environments where readiness determines whether traffic
should be routed to the service.

Kubernetes will stop sending traffic when readiness fails.
"""
@app.get("/readyz", tags=["health"])
async def readyz() -> Dict[str, str]:
    if state.shutting_down:
        raise HTTPException(status_code=503, detail="not ready")
    return {"status": "ready"}


# Testing the trace
# @app.get("/debug-trace")
# async def debug_trace() -> Dict[str, str]:
#     tracer = trace.get_tracer("myapp.debug")
#     with tracer.start_as_current_span("debug-span") as span:
#         span.set_attribute("debug", True)
#         return {"status": "ok"}
