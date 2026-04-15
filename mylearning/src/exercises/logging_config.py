# logging config module 
# it uses the same style as myapp (JSON in prod, plain in dev).   
# You don’t need per‑request correlation IDs here because 
# mylearning is called by tests or by myapp; correlation 
# is handled at the service boundary. 
# Note: In your tests (or when using mylearning directly), 
#       call setup_logging() once at process start.
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