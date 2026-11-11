import json
from pathlib import Path
from urllib.parse import urlsplit

from pydantic import AliasChoices, Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = BASE_DIR / ".env"


class Settings(BaseSettings):
    ENVIRONMENT: str = "local"

    SUPABASE_URL: str
    SUPABASE_SECRET_KEY: str
    SUPABASE_ANON_KEY: str | None = None
    PUBLIC_CATALOG_BASE_URL: str | None = None
    PUBLIC_API_BASE_URL: str | None = None

    BACKEND_CORS_ORIGINS: str | None = Field(
        default=None,
        validation_alias=AliasChoices("BACKEND_CORS_ORIGINS", "CORS_ORIGINS"),
    )

    INSTAGRAM_ACCESS_TOKEN: str | None = None
    INSTAGRAM_BUSINESS_ACCOUNT_ID: str | None = None
    META_APP_ID: str | None = None
    META_APP_SECRET: str | None = None
    VERIFY_TOKEN: str | None = None
    WHATSAPP_ACCESS_TOKEN: str | None = None
    WHATSAPP_VERIFY_TOKEN: str | None = None

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

    @model_validator(mode="after")
    def validate_production_configuration(self):
        if self.ENVIRONMENT.lower() in {"local", "development", "dev"}:
            return self

        supabase_url = urlsplit(self.SUPABASE_URL)
        if supabase_url.scheme != "https" or not supabase_url.hostname:
            raise ValueError("SUPABASE_URL must use HTTPS outside development")

        catalog_url = urlsplit((self.PUBLIC_CATALOG_BASE_URL or "").strip())
        if (
            catalog_url.scheme != "https"
            or not catalog_url.hostname
            or catalog_url.hostname in {"localhost", "127.0.0.1", "::1"}
            or catalog_url.hostname.endswith(".localhost")
            or catalog_url.hostname.endswith(".example")
            or catalog_url.path not in {"", "/"}
            or catalog_url.query
            or catalog_url.fragment
        ):
            raise ValueError(
                "Set PUBLIC_CATALOG_BASE_URL to the public HTTPS app origin outside development"
            )

        razorpay_configured = bool(
            self.RAZORPAY_KEY_ID or self.RAZORPAY_KEY_SECRET
        )
        if razorpay_configured:
            callback_url = urlsplit(self.RAZORPAY_CALLBACK_URL)
            if (
                not self.RAZORPAY_KEY_ID
                or not self.RAZORPAY_KEY_SECRET
                or not self.RAZORPAY_WEBHOOK_SECRET
                or callback_url.scheme != "https"
                or not callback_url.hostname
                or callback_url.hostname in {"localhost", "127.0.0.1", "::1", "example.com"}
                or callback_url.hostname.endswith(".localhost")
                or callback_url.hostname.endswith(".example")
            ):
                raise ValueError(
                    "Configure Razorpay keys, RAZORPAY_WEBHOOK_SECRET, and a public HTTPS RAZORPAY_CALLBACK_URL"
                )

        if self.RESEND_API_KEY and self.EMAIL_FROM.lower().endswith("@resend.dev"):
            raise ValueError(
                "Set EMAIL_FROM to a verified sender address when Resend is enabled outside development"
            )

        cloudinary_values = (
            self.CLOUDINARY_CLOUD_NAME,
            self.CLOUDINARY_API_KEY,
            self.CLOUDINARY_API_SECRET,
        )
        if any(cloudinary_values) and not all(cloudinary_values):
            raise ValueError(
                "Set all Cloudinary credentials or leave all unset outside development"
            )

        return self

    @property
    def cors_origins(self) -> list[str]:
        if self.ENVIRONMENT.lower() in {"local", "development", "dev"}:
            return ["*"]

        raw_value = (self.BACKEND_CORS_ORIGINS or "").strip()

        if raw_value == "*":
            raise ValueError("Wildcard CORS origins are only allowed in local development")
        if not raw_value:
            raise ValueError(
                "BACKEND_CORS_ORIGINS must be set outside development"
            )

        if raw_value.startswith("["):
            parsed = json.loads(raw_value)
            if not isinstance(parsed, list) or not all(
                isinstance(origin, str) for origin in parsed
            ):
                raise ValueError("CORS origins must be a list of strings")
            origins = [origin.strip() for origin in parsed if origin.strip()]
            if "*" in origins:
                raise ValueError(
                    "Wildcard CORS origins are only allowed in local development"
                )
            self._validate_production_origins(origins)
            return origins

        origins = [
            origin.strip()
            for origin in raw_value.split(",")
            if origin.strip()
        ]
        if "*" in origins:
            raise ValueError(
                "Wildcard CORS origins are only allowed in local development"
            )
        self._validate_production_origins(origins)
        return origins

    def _validate_production_origins(self, origins: list[str]) -> None:
        if self.ENVIRONMENT.lower() in {"local", "development", "dev"}:
            return
        if not origins:
            raise ValueError(
                "BACKEND_CORS_ORIGINS must include the deployed app origin"
            )
        for origin in origins:
            parsed = urlsplit(origin)
            if (
                parsed.scheme != "https"
                or not parsed.hostname
                or parsed.path not in {"", "/"}
                or parsed.query
                or parsed.fragment
            ):
                raise ValueError(
                    "Production BACKEND_CORS_ORIGINS entries must be HTTPS origins"
                )

    @property
    def cors_origin_regex(self) -> str | None:
        return None


settings = Settings()