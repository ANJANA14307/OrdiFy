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
    product_id: str
    quantity: int = Field(gt=0)
    unit_price: Optional[float] = Field(default=None, gt=0)
    variant_notes: Optional[str] = None


class OrderCreate(BaseModel):
    customer_id: str
    source: OrderSource = "manual"
    notes: Optional[str] = None
    custom_variant: Optional[str] = None
    items: List[OrderItemCreate]


class OrderStatusUpdate(BaseModel):
    status: OrderStatus