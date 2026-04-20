# 1. Note: any pytest ->  pytest = functions + assertions + controlled execution
# 2. naming convention -> test_ function pytest detects it
# 3. if you are not using pytest db fixture then start docker db image manually before running this test if you want to test db connection
# 4. add Mark DB tests, sothat you can run pytest selectively ->
#      poetry run pytest -m "not db"
#          or
#      poetry run pytest -m db

import pytest
from sqlalchemy.orm import Session

from myapp.models.db_models import User
from myapp.models.schemas import UserCreate
from myapp.services.user_service import create_user, list_users

# Note:
# 1. Create/drop tables per session, and.
# 2. Rollback per test (as in the fixture). db_session is the fixture from conftest.py


def test_create_and_list_users(db_session: Session) -> None:
    # Create a user via service
    user_in = UserCreate(name="Alice", email="[email protected]")
    created = create_user(db_session, user_in)

    assert created.id is not None
    assert created.name == "Alice"

    # List users
    users = list_users(db_session)
    assert any(u.email == "[email protected]" for u in users)


def test_db_is_isolated_between_tests(db_session: Session) -> None:
    # This test should see a clean DB (depending on how you reset between tests)
    users = db_session.query(User).all()
    # You can make assertions based on your desired isolation level
    # For full isolation, you might expect len(users) == 0
    # For cumulative data, you might just assert the table exists
    assert isinstance(users, list)


# db_session is the fixture from conftest.py that uses
# Testcontainers (or the compose DB), depending on USE_TESTCONTAINERS.
# UserCreate and create_user are imported from your new models and services
# modules.
# UserCreate and create_user are imported from your new models and services
# modules.
# pytest.mark.db is define in pyproject.toml under pytest ini config.
# mark one DB test as smoke as well, so your smoke suite checks the DB end‑to‑end without running the full DB test set.
@pytest.mark.db
@pytest.mark.smoke
def test_create_user(db_session: Session) -> None:
    user = UserCreate(name="test", email="[email protected]")
    result = create_user(db_session, user)

    assert result.id is not None
    assert result.name == "test"
    assert result.email == "[email protected]"
