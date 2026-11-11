from typing import List, Literal, Optional

import re

from pydantic import BaseModel, Field, field_validator


OrderStatus = Literal[
    "new",
    "confirmed",
    "packed",
    "shipped",
    "delivered",
    "cancelled",
]

OrderSource = Literal[
    "dm",
    "comment",
    "manual",
    "whatsapp",
]


class OrderItemCreate(BaseModel):
    product_id: str = Field(..., min_length=1)
    quantity: int = Field(..., gt=0)
    unit_price: Optional[float] = Field(default=None, gt=0)
    variant_notes: Optional[str] = Field(default=None, max_length=500)


class OrderCreate(BaseModel):
    customer_id: str = Field(..., min_length=1)
    source: OrderSource = "manual"
    notes: Optional[str] = Field(default=None, max_length=1000)
    custom_variant: Optional[str] = Field(default=None, max_length=500)
    delivery_pincode: Optional[str] = Field(default=None, min_length=6, max_length=6)
    items: List[OrderItemCreate] = Field(..., min_length=1)

    @field_validator("delivery_pincode")
    @classmethod
    def validate_delivery_pincode(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        cleaned = value.strip()
        if not re.fullmatch(r"\d{6}", cleaned):
            raise ValueError("Pincode must be exactly 6 digits")
        return cleaned


class OrderStatusUpdate(BaseModel):
    status: OrderStatus