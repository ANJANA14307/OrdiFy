from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class CatalogProductSuggestion(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    brand: str | None = Field(default=None, max_length=120)
    category: str = Field(min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=2000)
    images: list[str] = Field(default_factory=list, max_length=8)

    @field_validator("name", "category")
    @classmethod
    def trim_required_text(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("This field is required")
        return cleaned

    @field_validator("brand", "description")
    @classmethod
    def trim_optional_text(cls, value: str | None) -> str | None:
        return value.strip() or None if value is not None else None

    @field_validator("images")
    @classmethod
    def secure_images(cls, values: list[str]) -> list[str]:
        cleaned = list(dict.fromkeys(value.strip() for value in values if value.strip()))
        if any(len(value) > 2048 or not value.startswith("https://") for value in cleaned):
            raise ValueError("Images must be secure image URLs")
        return cleaned


class ListingVariantCreate(BaseModel):
    code: str = Field(min_length=1, max_length=80, pattern=r"^[A-Z0-9]+(-[A-Z0-9]+)*$")
    attributes: dict[str, Any] = Field(default_factory=dict)
    price: float | None = Field(default=None, gt=0)
    stock: int = Field(default=0, ge=0)
    is_active: bool = True


class BusinessListingCreate(BaseModel):
    catalog_product_id: UUID
    price: float = Field(gt=0)
    stock: int = Field(ge=0)
    variants: list[ListingVariantCreate] = Field(default_factory=list, max_length=100)
    delivery_override: dict[str, Any] | None = None
    return_policy_override: dict[str, Any] | None = None


class BusinessListingUpdate(BaseModel):
    price: float | None = Field(default=None, gt=0)
    stock: int | None = Field(default=None, ge=0)
    is_active: bool | None = None
    delivery_override: dict[str, Any] | None = None
    return_policy_override: dict[str, Any] | None = None


class ProductCatalogMappingCreate(BaseModel):
    catalog_product_id: UUID


class CatalogProductReview(BaseModel):
    status: str
    review_notes: str | None = Field(default=None, max_length=2000)

    @field_validator("status")
    @classmethod
    def valid_review_status(cls, value: str) -> str:
        if value not in {"approved", "rejected"}:
            raise ValueError("Review status must be approved or rejected")
        return value

    @field_validator("review_notes")
    @classmethod
    def clean_review_notes(cls, value: str | None) -> str | None:
        return value.strip() or None if value is not None else None
