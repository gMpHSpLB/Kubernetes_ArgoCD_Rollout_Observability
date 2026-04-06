#Schema
#Purpose : API input/output

# Using pydantic:
#     Pydantic is a Python library for defining data models with validation 
#     and type hints, and then automatically parsing and validating data (usually JSON or dicts) into those models.
# Pydantic will:
#     - Validate incoming data (types, required fields).
#     - Coerce compatible types (e.g., "1" → 1 if field is int).
#     - Give you .dict() / .model_dump() for clean serialization.
# It’s heavily used with FastAPI to define request/response schemas 
# and config classes (like your Settings), because FastAPI reads Pydantic models to auto-generate OpenAPI docs and validate HTTP input.
from pydantic import BaseModel, ConfigDict

# Define simple schemas to shape input/output:
class UserBase(BaseModel):
    email: str


class UserCreate(UserBase):
    name: str


class UserRead(UserBase):
    id: int
    name: str

    model_config = ConfigDict(from_attributes=True)  # for SQLAlchemy ORM objects