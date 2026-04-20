# Auto-start DB in pytest
# No manual docker command
# Tests are self-contained

# Local	: Uses Testcontainers
# Docker : Uses docker-compose DB
# To achieve above
#    use testcontainers library : poetry add --group dev testcontainers psycopg2-binary2

# To use Testcontainers cleanly with your new core/db.py (SQLAlchemy, SessionLocal), you should:
#   Let Testcontainers create a real Postgres and a SQLAlchemy engine for tests.
#   Override SessionLocal during tests so app code uses the container DB.
#   Keep the option to fall back to the compose DB if you want.
# So,
# Note:
#   When USE_TESTCONTAINERS=true: a Postgres Docker container is started once per test session; all tests use it.
#   When USE_TESTCONTAINERS=false: tests point at your compose DB (db:5432/mydb) using the same credentials as dev.

import os
from collections.abc import Generator

# Here is a minimal test that uses the new db_session
# fixture and your models:
import pytest
from _pytest.config import Config
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

# Note:
# This guarantees every pytest worker process for myapp
# initializes your logging config.
from myapp.logging_config import setup_logging
from myapp.models.db_models import Base


def pytest_configure(config: Config) -> None:
    setup_logging()


USE_TESTCONTAINERS = os.getenv("USE_TESTCONTAINERS", "false").lower() == "true"

if USE_TESTCONTAINERS:
    from testcontainers.postgres import PostgresContainer


@pytest.fixture(scope="session")
def engine() -> Generator[Engine, None, None]:
    """
    Create a SQLAlchemy engine for tests.

    - If USE_TESTCONTAINERS=true: start a Postgres container and use its URL.
    - Else: use the same DB URL as your docker-compose dev DB
      (postgresql://myuser:mypassword@db:5432/mydb).
    """
    if USE_TESTCONTAINERS:
        with PostgresContainer("postgres:15") as postgres:
            url = postgres.get_connection_url()  # SQLAlchemy-compatible URL
            test_engine = create_engine(url)
            yield test_engine
    else:
        # point tests to Minikube DB or a compose DB
        host = os.getenv("DB_HOST", "db")
        port = int(os.getenv("DB_PORT", "5432"))
        name = os.getenv("DB_NAME", "mydb")
        user = os.getenv("DB_USER", "myuser")
        password = os.getenv("DB_PASSWORD", "mypassword")
        url = f"postgresql://{user}:{password}@{host}:{port}/{name}"
        test_engine = create_engine(url)
        yield test_engine


# Note:
# Base.metadata.create_all and drop_all ensure a fresh schema for tests.
@pytest.fixture(scope="session")
def db_session_factory(engine: Engine) -> Generator[sessionmaker[Session], None, None]:
    """
    Create all tables once per session and return a session factory.

    Tables are dropped after the whole test session finishes.
    """
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal: sessionmaker[Session] = sessionmaker(
        autocommit=False, autoflush=False, bind=engine
    )

    yield TestingSessionLocal

    Base.metadata.drop_all(bind=engine)


# Rollback per test (as in the fixture).
@pytest.fixture(scope="function")
def db_session(
    db_session_factory: sessionmaker[Session],
) -> Generator[Session, None, None]:
    """
    Provide a fresh DB session per test.

    Rolls back and closes after each test.
    """
    db = db_session_factory()
    try:
        yield db
        db.commit()
    finally:
        db.rollback()
        db.close()


# autouse fixture overrides SessionLocal so your normal app DB code (DI, get_db)
# uses this test engine automatically.
@pytest.fixture(autouse=True)
def override_app_sessionlocal(
    monkeypatch: pytest.MonkeyPatch, db_session_factory: sessionmaker[Session]
) -> None:
    """
    Override myapp.core.db.SessionLocal so app code uses the test DB.

    This way, any code that calls SessionLocal() (e.g., in get_db)
    will use the Testcontainers / test engine instead of the real one.
    """

    def _test_sessionlocal() -> Session:
        return db_session_factory()

    # Monkeypatch the SessionLocal used in the app
    # Because we monkeypatch SessionLocal, your FastAPI
    # dependencies (using get_db) also work in integration tests with TestClient
    monkeypatch.setattr("myapp.core.db.SessionLocal", _test_sessionlocal)
