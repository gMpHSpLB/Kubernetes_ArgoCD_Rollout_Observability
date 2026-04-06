#Main App : FastAPI-style entrypoint
# src/myapp/main.py
from fastapi import FastAPI
from myapp.api.v1.routes import router as v1_router
from myapp.core.config import settings

app = FastAPI(title=settings.app_name)

app.include_router(v1_router, prefix="/api/v1")


@app.get("/health", tags=["health"])
def health() -> dict:
    return {"status": "ok", "env": settings.app_env}