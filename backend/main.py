import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

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
from routers.product_variants import router as product_variants_router
from routers.delivery_fees import router as delivery_fees_router
from routers.catalogs import router as catalogs_router
from routers.whatsapp_orders import router as whatsapp_orders_router
from routers.whatsapp_orders import webhook_router as whatsapp_webhook_router
from routers.instagram_redirect import router as instagram_redirect_tools_router
from routers.instagram_redirect import redirect_router as instagram_redirect_router
from routers.instagram_redirect import webhook_router as instagram_webhook_router
from routers.profile import router as profile_router
from routers.ai_chat import router as ai_chat_router
from routers.returns import router as returns_router
from routers.shared_catalog import router as shared_catalog_router


logger = logging.getLogger("ordify.api")

app = FastAPI(
    title="OrdiFy Backend",
    version="1.0.0",
    description="Production-ready API layer for OrdiFy.",
    debug=False,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Accept", "Authorization", "Content-Type", "X-Requested-With"],
)


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = (
        "camera=(), microphone=(), geolocation=()"
    )
    if settings.ENVIRONMENT.lower() not in {"local", "development", "dev"}:
        response.headers["Strict-Transport-Security"] = (
            "max-age=31536000; includeSubDomains"
        )
    return response


@app.exception_handler(StarletteHTTPException)
async def handle_http_exception(request: Request, exc: StarletteHTTPException):
    detail = exc.detail
    if exc.status_code >= 500:
        logger.error(
            "HTTP %s returned for %s",
            exc.status_code,
            request.url.path,
        )
        detail = "Internal server error"
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": detail},
        headers=exc.headers,
    )


@app.exception_handler(Exception)
async def handle_unexpected_exception(request: Request, exc: Exception):
    logger.exception("Unhandled API error for %s", request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )


app.include_router(auth_router)
app.include_router(profile_router)
app.include_router(instagram_router)
app.include_router(products_router)
app.include_router(product_variants_router)
app.include_router(delivery_fees_router)
app.include_router(catalogs_router)
app.include_router(whatsapp_orders_router)
app.include_router(whatsapp_webhook_router)
app.include_router(instagram_redirect_tools_router)
app.include_router(instagram_redirect_router)
app.include_router(instagram_webhook_router)
app.include_router(customers_router)
app.include_router(orders_router)
app.include_router(returns_router)
app.include_router(shared_catalog_router)
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