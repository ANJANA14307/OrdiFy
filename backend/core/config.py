from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = BASE_DIR / ".env"


class Settings(BaseSettings):
    ENVIRONMENT: str = "local"

    SUPABASE_URL: str
    SUPABASE_SECRET_KEY: str
    SUPABASE_ANON_KEY: str | None = None

    BACKEND_CORS_ORIGINS: str = (
        "http://localhost:8080,http://127.0.0.1:8080,"
        "http://localhost:8000,http://127.0.0.1:8000,"
        "https://localhost:8080,https://127.0.0.1:8080"
    )

    INSTAGRAM_ACCESS_TOKEN: str | None = None
    INSTAGRAM_BUSINESS_ACCOUNT_ID: str | None = None
    META_APP_ID: str | None = None
    META_APP_SECRET: str | None = None
    VERIFY_TOKEN: str | None = None

    CLOUDINARY_CLOUD_NAME: str | None = None
    CLOUDINARY_API_KEY: str | None = None
    CLOUDINARY_API_SECRET: str | None = None

    GEMINI_API_KEY: str | None = None
    GEMINI_MODEL: str = "gemini-2.0-flash"

    RAZORPAY_KEY_ID: str | None = None
    RAZORPAY_KEY_SECRET: str | None = None
    RAZORPAY_WEBHOOK_SECRET: str | None = None
    RAZORPAY_CALLBACK_URL: str = "https://example.com/payment-success"

    STRIPE_SECRET_KEY: str | None = None
    STRIPE_WEBHOOK_SECRET: str | None = None

    RESEND_API_KEY: str | None = None
    EMAIL_FROM: str = "OrdiFy <onboarding@resend.dev>"

    model_config = SettingsConfigDict(
        env_file=ENV_FILE,
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def cors_origins(self) -> list[str]:
        raw_value = self.BACKEND_CORS_ORIGINS.strip()

        if raw_value == "*" or not raw_value:
            return ["*"]

        return [
            origin.strip()
            for origin in raw_value.split(",")
            if origin.strip()
        ]


settings = Settings()