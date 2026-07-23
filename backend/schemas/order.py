from typing import List, Literal, Optional

from pydantic import BaseModel, Field


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
    items: List[OrderItemCreate] = Field(..., min_length=1)


class OrderStatusUpdate(BaseModel):
    status: OrderStatus