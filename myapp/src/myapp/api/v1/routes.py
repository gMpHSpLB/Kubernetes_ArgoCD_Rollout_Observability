# API Layer
# API layer = thin
# Just request → service → response
# FastAPI router that uses the service and DB dependency:
# src/myapp/api/v1/routes.py
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from myapp.deps.dependencies import get_db
from myapp.models.schemas import UserCreate, UserRead
from myapp.services.user_service import create_user, get_user, list_users

router = APIRouter(tags=["users"])


@router.get("/users", response_model=List[UserRead])
def read_users(limit: int = 100, db: Session = Depends(get_db)) -> List[UserRead]:
    return list_users(db, limit=limit)


@router.get("/users/{user_id}", response_model=UserRead)
def read_user(
    user_id: int,
    db: Session = Depends(get_db),
) -> UserRead:
    user: Optional[UserRead] = get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.post("/users", response_model=UserRead, status_code=201)
def create_user_endpoint(
    user_in: UserCreate,
    db: Session = Depends(get_db),
) -> UserRead:
    return create_user(db, user_in)
