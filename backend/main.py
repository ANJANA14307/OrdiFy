from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.config import settings

from routers.activity import router as activity_router
from routers.ai_suggestions import router as ai_suggestions_router
from routers.analytics import router as analytics_router
from routers.auth import router as auth_router
from routers.customers import router as customers_router
from routers.instagram import router as instagram_router
from routers.invoices import router as invoices_router
from routers.notifications import router as notifications_router
from routers.orders import router as orders_router
from routers.payments import router as payments_router
from routers.products import router as products_router
from routers.profile import router as profile_router
from routers.ai_chat import router as ai_chat_router


app = FastAPI(
    title="OrdiFy Backend",
    version="1.0.0",
    description="Production-ready API layer for OrdiFy.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(profile_router)
app.include_router(instagram_router)
app.include_router(products_router)
app.include_router(customers_router)
app.include_router(orders_router)
app.include_router(payments_router)
app.include_router(invoices_router)
app.include_router(notifications_router)
app.include_router(activity_router)
app.include_router(analytics_router)
app.include_router(ai_suggestions_router)
app.include_router(ai_chat_router)

@app.get("/")
async def root():
    return {
        "app": "OrdiFy Backend",
        "status": "running",
        "environment": settings.ENVIRONMENT,
        "version": "1.0.0",
    }


@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "environment": settings.ENVIRONMENT,
    }