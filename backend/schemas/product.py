from typing import Optional

from pydantic import BaseModel, Field


class ProductCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    description: Optional[str] = Field(default=None, max_length=1000)
    price: float = Field(..., gt=0)
    stock_count: int = Field(..., ge=0)
    image_url: Optional[str] = None
    low_stock_threshold: int = Field(default=5, ge=0)


class ProductUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    description: Optional[str] = Field(default=None, max_length=1000)
    price: Optional[float] = Field(default=None, gt=0)
    stock_count: Optional[int] = Field(default=None, ge=0)
    image_url: Optional[str] = None
    low_stock_threshold: Optional[int] = Field(default=None, ge=0)