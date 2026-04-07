# Models Layer - SQLAlchemy model
# Purpose : Database structure
from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import DeclarativeBase


# A minimal SQLAlchemy User model:
class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    email = Column(String, unique=True, index=True)
