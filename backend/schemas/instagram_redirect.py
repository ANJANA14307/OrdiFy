import re
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator


class InstagramConfigUpdate(BaseModel):
    is_enabled: bool = False
    trigger_keywords: list[str] = Field(default_factory=list, max_length=20)
    reply_text: str = Field(min_length=1, max_length=1000)

    @field_validator("trigger_keywords")
    @classmethod
    def normalize_keywords(cls, values: list[str]) -> list[str]:
        normalized = list(
            dict.fromkeys(value.strip().lower() for value in values if value.strip())
        )
        if any(len(value) > 40 for value in normalized):
            raise ValueError("Trigger keywords must be 40 characters or fewer")
        return normalized

    @field_validator("reply_text")
    @classmethod
    def validate_reply_text(cls, value: str) -> str:
        cleaned = value.strip()
        if "{catalog_link}" not in cleaned or "{whatsapp_link}" not in cleaned:
            raise ValueError(
                "Reply text must include both {catalog_link} and {whatsapp_link}"
            )
        return cleaned


class InstagramRedirectDestination(BaseModel):
    destination: Literal["catalog", "whatsapp", "product"]
    tag: str = "bio"
    product_id: str | None = None

    @field_validator("tag")
    @classmethod
    def validate_tag(cls, value: str) -> str:
        cleaned = value.strip().lower()
        if not re.fullmatch(r"[a-z0-9_-]{1,40}", cleaned):
            raise ValueError("Tracking tag must use letters, numbers, hyphens, or underscores")
        return cleaned

    @model_validator(mode="after")
    def validate_product_id(self):
        if self.destination == "product" and not self.product_id:
            raise ValueError("Product ID is required for a product redirect")
        if self.destination != "product" and self.product_id:
            raise ValueError("Product ID is only valid for a product redirect")
        return self
