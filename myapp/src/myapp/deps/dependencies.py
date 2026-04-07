# Dependency Injection (DB dependency)
# This is how FastAPI injects DB session into routes
# No manual connection handling in business logic
# Your existing user_service.py should receive dependencies (db, config) as arguments, not import globals. That’s the DI mindset.

# src/myapp/deps/dependencies.py
from typing import Generator

from sqlalchemy.orm import Session

from myapp.core.db import SessionLocal


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
