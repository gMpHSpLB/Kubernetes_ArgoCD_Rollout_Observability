# mylearning/tests/test_health.py
import pytest

from exercises.health import liveness, readiness


@pytest.mark.smoke
def test_liveness_ok() -> None:
    result = liveness()
    assert result["status"] == "ok"


@pytest.mark.smoke
def test_readiness_ok() -> None:
    result = readiness()
    assert result["status"] == "ready"
