# myapp/tests/test_health.py
import pytest
from fastapi.testclient import (
    TestClient,  # TestClient, which matches the FastAPI testing pattern with pytest.
)

from myapp.main import (
    app,  # Uses src/myapp/main.py The FastAPI app instance is called app at the bottom of that file.
    state,
)

client = TestClient(app)

"""
Here, @pytest.mark.smoke is pytest marker defined in *.toml project file to run smake test "pytest -m smoke"
"""


@pytest.mark.smoke
def test_healthz_ok() -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"


@pytest.mark.smoke
def test_readyz_ok_when_not_shutting_down() -> None:
    # Default state at test start should be "not shutting down"
    state.shutting_down = False

    response = client.get("/readyz")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ready"


"""
state.shutting_down is a simple global flag in main.py. 
To test readiness failing during shutdown, we can import 
the state object and flip it.
"""


@pytest.mark.smoke
def test_readyz_returns_503_when_shutting_down() -> None:
    # Arrange: simulate shutdown
    state.shutting_down = True

    response = client.get("/readyz")

    assert response.status_code == 503
    data = response.json()
    # FastAPI converts HTTPException(detail="not ready") to {"detail": "not ready"}
    assert data["detail"] == "not ready"

    # Cleanup so other tests are not affected
    state.shutting_down = False
