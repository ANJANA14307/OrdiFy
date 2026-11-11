import re
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator


CODE_PATTERN = re.compile(r"^[A-Z0-9]+(?:-[A-Z0-9]+)*$")


def validate_code(value: str) -> str:
    if not CODE_PATTERN.fullmatch(value):
        raise ValueError("Code must use uppercase letters, numbers, and hyphens only")
    return value


class ProductVariantCreate(BaseModel):
    code: str = Field(..., min_length=1, max_length=80)
    attributes: dict[str, Any] = Field(default_factory=dict)
    price: float = Field(..., gt=0)
    stock: int = Field(..., ge=0)
    is_active: bool = True

    @field_validator("code")
    @classmethod
    def code_format(cls, value: str) -> str:
        return validate_code(value)


class ProductVariantUpdate(BaseModel):
    code: Optional[str] = Field(default=None, min_length=1, max_length=80)
    attributes: Optional[dict[str, Any]] = None
    price: Optional[float] = Field(default=None, gt=0)
    stock: Optional[int] = Field(default=None, ge=0)
    is_active: Optional[bool] = None

    @field_validator("code")
    @classmethod
    def code_format(cls, value: Optional[str]) -> Optional[str]:
        if value is not None:
            return validate_code(value)
        return value
