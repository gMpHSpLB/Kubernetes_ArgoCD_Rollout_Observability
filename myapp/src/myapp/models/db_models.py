# Models Layer - SQLAlchemy model
# Purpose : Database structure
from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import declarative_base

# A minimal SQLAlchemy User model:
Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    email = Column(String, unique=True, index=True)
