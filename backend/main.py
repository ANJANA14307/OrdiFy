from fastapi import FastAPI
from core.config import settings
from routers.auth import router as auth_router
from routers.instagram import router as instagram_router
from routers.products import router as products_router
from routers.orders import router as orders_router
from routers.customers import router as customers_router
from routers.payments import router as payments_router
from routers.invoices import router as invoices_router

app = FastAPI(title="OrdiFY Backend", version="1.0.0")

app.include_router(auth_router)
app.include_router(instagram_router)
app.include_router(products_router)
app.include_router(orders_router)
app.include_router(customers_router)
app.include_router(payments_router)
app.include_router(invoices_router)


@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "environment": settings.ENVIRONMENT,
    }