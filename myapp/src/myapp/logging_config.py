"""
Think of this file as the app’s logging control room:
it decides what logs look like, makes sure every request
gets a unique tracking ID, and ensures request start/end/errors
are recorded consistently. That means when something breaks in
production, you can trace one user request across many log lines
instead of guessing which messages belong together.

It also adds a per-request correlation ID so all log lines for one
HTTP request can be tied together.
"""

import logging
import os
import sys
import time
import uuid
from collections.abc import Awaitable, Callable
from contextvars import ContextVar

from fastapi import Request, Response
from pythonjsonlogger.jsonlogger import JsonFormatter  # type: ignore[attr-defined]

"""
The ContextVar named _request_id_ctx_var stores the current
request ID for the active request context. set_request_id()
saves the ID, and get_request_id() retrieves it later, which
is helpful when deeper code needs to include the same request
ID in its logs.
In the middleware, the app reads the incoming
x-request-id header or generates a new UUID, then stores it in
that context variable.

This creates a request-scoped storage slot. It is important because
FastAPI is asynchronous, so multiple requests can run at the same
time; a normal global variable would mix them up. ContextVar keeps
each request’s ID isolated from others
"""
_request_id_ctx_var: ContextVar[str | None] = ContextVar("request_id", default=None)


"""
get_request_id() simply reads the current request’s ID, and set_request_id()
stores one if needed. In your code, the middleware sets it at the start of each
request and resets it at the end.

Why the request ID matters
The request ID is a correlation ID. It lets you trace everything related to one request across multiple log lines. That becomes very useful when:

    one request hits several functions,
    you are debugging an error reported by a user,
    you want to follow an issue through middleware, service code, and database calls,
    or you need to match client-side errors with server-side logs.

For example:

    client sends x-request-id: abc123
    your app logs the start of the request
    a service function logs a warning
    a database call logs an error
    the response goes back with the same x-request-id

Now all those logs can be grouped together.
"""


def get_request_id() -> str | None:
    return _request_id_ctx_var.get()


def set_request_id(request_id: str | None) -> None:
    _request_id_ctx_var.set(request_id)


"""
setup_logging() configures the root logger, clears existing handlers,
and attaches one StreamHandler that writes to stdout.
In dev, it uses a readable plain-text formatter; in other
environments, it uses pythonjsonlogger.JsonFormatter so
logs become JSON objects. It also redirects uvicorn,
uvicorn.access, uvicorn.error, and fastapi logs into the
same logging pipeline so startup, server, and app logs all
follow the same format.

This function configures how logs are printed.

It does a few important things:
clears existing handlers so you do not get duplicate log lines,
reads LOG_LEVEL from the environment,
reads APP_ENV to decide between development and production formatting,
sends logs to standard output,
sets the root logger level,
and changes logging behavior for uvicorn and fastapi so they follow your setup.
"""


def setup_logging() -> None:
    logger = logging.getLogger()
    # clears existing handlers so you do not get duplicate
    # log lines
    logger.handlers.clear()

    # reads LOG_LEVEL from the environment
    log_level = os.getenv("LOG_LEVEL", "INFO").upper()
    # reads APP_ENV to decide between development and production formatting
    env = os.getenv("APP_ENV", "dev").lower()

    print(f"LOGGING: using env={env}")

    # sends logs to standard output
    handler = logging.StreamHandler(sys.stdout)

    # sets the root logger level
    if env == "dev":
        # In dev, logs are human-friendly:
        # 2026-04-11 01:00:00 INFO [myapp.request] request_start
        formatter = logging.Formatter(
            fmt="%(asctime)s %(levelname)s [%(name)s] %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
    else:
        # formatter = jsonlogger.JsonFormatter(
        formatter = JsonFormatter(
            # In non-dev environments, logs become JSON:
            # {
            # "timestamp": "...",
            # "level": "INFO",
            # "name": "myapp.request",
            # ...
            # }
            fmt="%(asctime)s %(levelname)s %(name)s %(message)s %(request_id)s %(path)s %(method)s %(status_code)s %(duration_ms)s",
            rename_fields={"asctime": "timestamp", "levelname": "level"},
            datefmt="%Y-%m-%dT%H:%M:%SZ",
        )
    # Changes logging behavior for uvicorn
    # and fastapi so they follow your setup
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(log_level)

    for name in ("uvicorn", "uvicorn.access", "uvicorn.error", "fastapi"):
        lib_logger = logging.getLogger(name)
        lib_logger.handlers.clear()
        # Why propagate = True is set.
        # makes library loggers pass their messages upward to
        # your root logger instead of using their own separate
        # formatting. The result is consistent log output across
        # your app and server framework
        lib_logger.propagate = True


"""
Middleware behavior
logging_middleware() wraps every HTTP request.
At the start, it logs request_start with the
request ID, path, and method; after the request
completes, it logs request_end with the status
code and adds x-request-id to the response headers
so clients can reference it later. If an exception
occurs, it logs request_error with stack trace details
using logger.exception(), which is important for debugging
failures.
"""


async def logging_middleware(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    # It reads x-request-id from the incoming request headers.
    # If the client did not send one, it generates a new UUID.
    request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
    # It stores that request ID in the ContextVar.
    token = _request_id_ctx_var.set(request_id)
    # It starts a timer.
    start = time.perf_counter()
    # It logs request_start.
    logger = logging.getLogger("myapp.request")

    try:
        logger.info(
            "request_start",
            extra={
                "request_id": request_id,
                "path": request.url.path,
                "method": request.method,
            },
        )
        # It calls the actual FastAPI endpoint with await call_next(request).
        response = await call_next(request)
        # If the request succeeds, it logs request_end with status code and duration.
        duration_ms = round((time.perf_counter() - start) * 1000, 2)
        logger.info(
            "request_end",
            extra={
                "request_id": request_id,
                "path": request.url.path,
                "method": request.method,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
            },
        )
        # It adds x-request-id to the response
        # headers so the client can see it.
        response.headers["x-request-id"] = request_id
        return response
    except (
        Exception
    ):  # If an exception happens, it logs request_error with stack trace.
        duration_ms = round((time.perf_counter() - start) * 1000, 2)
        logger.exception(
            "request_error",
            extra={
                "request_id": request_id,
                "path": request.url.path,
                "method": request.method,
                "duration_ms": duration_ms,
            },
        )
        raise
    finally:  # It always resets the context variable afterward.
        _request_id_ctx_var.reset(token)
