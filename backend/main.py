from fastapi import FastAPI
from core.config import settings
from routers.auth import router as auth_router
app = FastAPI(title="OrdiFY Backend", version="1.0.0")
app.include_router(auth_router)

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "environment": settings.ENVIRONMENT
    }
