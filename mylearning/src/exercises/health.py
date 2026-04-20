# mylearning/src/exercises/health.py
from __future__ import annotations

from typing import Dict


def liveness() -> Dict[str, str]:
    """
    Basic liveness check for the exercises package.

    Returns a simple dict that can be serialized by any caller
    (API, CLI, tests, etc.).
    """
    return {"status": "ok"}


def readiness() -> Dict[str, str]:
    """
    Basic readiness check for the exercises package.

    For now, this always returns ready. In the future you can:
    - Add checks for configuration
    - Validate that required resources or datasets exist
    - Wrap external checks if mylearning grows dependencies
    """
    return {"status": "ready"}
