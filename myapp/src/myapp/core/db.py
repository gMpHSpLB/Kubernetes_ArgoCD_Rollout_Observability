#Using SQLAlchemy engine
#set up the engine + session here
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from myapp.core.config import settings

#real Postgres
DATABASE_URL = (
    f"postgresql://{settings.db_user}:{settings.db_password}"
    f"@{settings.db_host}:{settings.db_port}/{settings.db_name}"
)

# Added pool_pre_ping=True for better reliability with pooled connections 
# (optional but common in production).
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)