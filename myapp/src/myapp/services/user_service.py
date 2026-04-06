#Service Layer
# Business logic lives here (NOT in API)
# Service functions that operate on User using a SQLAlchemy Session and 
# your settings if needed:
# src/myapp/services/user_service.py
from typing import List, Optional

from sqlalchemy.orm import Session

from myapp.models import db_models
from myapp.models.schemas import UserCreate, UserRead
from myapp.core.config import settings

# DI: db is injected from FastAPI via Depends(get_db).
# settings is available if you need env‑specific behavior (e.g., feature flags, 
# logging decisions).

def get_user(db: Session, user_id: int) -> Optional[UserRead]:
    user = db.get(db_models.User, user_id)
    if not user:
        return None
    return UserRead.model_validate(user)


def list_users(db: Session, limit: int = 100) -> List[UserRead]:
    users = db.query(db_models.User).limit(limit).all()
    return [UserRead.model_validate(u) for u in users]


def create_user(db: Session, user_in: UserCreate) -> UserRead:
    user = db_models.User(email=user_in.email, name=user_in.name)
    db.add(user)
    db.commit()
    db.refresh(user)
    # You could log or branch behavior based on settings.app_env if needed
    # e.g., if settings.app_env == "staging": ...
    return UserRead.model_validate(user)