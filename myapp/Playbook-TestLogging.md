You can fully test and verify your structured logging with what you already have; you just need to:

Start the dev stack.

Generate some requests.

Inspect myapp container logs and look for the expected log shape.

1. Ensure logging is wired into FastAPI
In main.py you already do (from observability.txt):

python
from myapp.logging_config import logging_middleware, setup_logging

def create_app() -> FastAPI:
    setup_logging()
    app = FastAPI(title=settings.app_name, lifespan=lifespan)

    app_env = os.getenv("APP_ENV", "dev")

    app.middleware("http")(logging_middleware)
    app.middleware("http")(metrics_middleware(app_env))

    app.include_router(v1_router, prefix="/api/v1")
    return app
So:

setup_logging() runs once at startup.

logging_middleware wraps every HTTP request.

Nothing extra to change here.

2. Start the dev stack with logging enabled
Your dev-up already passes LOG_LEVEL and APP_ENV into Docker:

bash
make dev-up
By default:

APP_ENV=dev → human‑readable logs via logging.Formatter.

LOG_LEVEL=info → you see INFO and above.

If you want to see JSON logs, restart with:

bash
APP_ENV=prod LOG_LEVEL=info make dev-up
In prod mode, setup_logging() switches to pythonjsonlogger.JsonFormatter.

3. Generate some requests
You already have a helper:

bash
make hit-api-multiple
Which does:

bash
for i in {1..20}; do curl -s -o /dev/null http://localhost:8000/docs; done
You can also hit a few different routes:

bash
curl -s -o /dev/null http://localhost:8000/docs
curl -s -o /dev/null http://localhost:8000/metrics
curl -s -o /dev/null http://localhost:8000/api/v1/users || true
Each of these should produce request_start and request_end log lines from logging_middleware.

4. Inspect logs from the myapp container
Use Docker logs:

bash
docker compose logs -f myapp
In dev mode (APP_ENV=dev), you should see lines like:

text
2026-04-14 02:30:01 INFO [myapp.request] request_start
2026-04-14 02:30:01 INFO [myapp.request] request_end
If you expand them (depending on how the formatter prints extra), you should see fields:

request_id (UUID or from incoming header).

path (e.g., /docs).

method (e.g., GET).

status_code and duration_ms on request_end.

In prod/JSON mode (APP_ENV=prod), lines will look like JSON objects (single line each), for example:

text
{"timestamp":"2026-04-14T02:30:01Z","level":"INFO","name":"myapp.request","message":"request_start","request_id":"...","path":"/docs","method":"GET"}
{"timestamp":"2026-04-14T02:30:01Z","level":"INFO","name":"myapp.request","message":"request_end","request_id":"...","path":"/docs","method":"GET","status_code":200,"duration_ms":3.21}
You can filter just your request logs:

bash
docker compose logs -f myapp | grep myapp.request
5. Verify correlation ID behavior
Call API without x-request-id:

bash
curl -s -D - http://localhost:8000/docs -o /dev/null
Response headers should contain x-request-id: <uuid>.

Logs should contain the same request_id for both request_start and request_end.

Call API with a custom x-request-id:

bash
curl -s -D - -H "x-request-id: test-123" http://localhost:8000/docs -o /dev/null
Response should echo x-request-id: test-123.

Logs should show request_id="test-123" for that request.

This proves the ContextVar and header propagation work.