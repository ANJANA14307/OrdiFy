from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from core.auth import get_logged_in_user
from services.gemini_service import generate_ai_text
from services.prompt_service import (
    build_customer_reply_prompt,
    build_general_chat_prompt,
    build_instagram_caption_prompt,
    build_inventory_advice_prompt,
    build_product_description_prompt,
    build_sales_analysis_prompt,
)


router = APIRouter(prefix="/ai", tags=["AI Tools"])


class AiGenerateRequest(BaseModel):
    type: Literal[
        "product_description",
        "instagram_caption",
        "customer_reply",
        "sales_analysis",
        "inventory_advice",
        "chat",
    ]

    product_name: str | None = Field(default=None, max_length=200)
    category: str | None = Field(default=None, max_length=200)
    price: str | None = Field(default=None, max_length=100)
    features: str | None = Field(default=None, max_length=1500)
    audience: str | None = Field(default=None, max_length=500)
    offer: str | None = Field(default=None, max_length=500)
    tone: str | None = Field(default=None, max_length=100)

    customer_message: str | None = Field(default=None, max_length=2000)
    product_context: str | None = Field(default=None, max_length=2000)

    summary: str | None = Field(default=None, max_length=4000)
    inventory_summary: str | None = Field(default=None, max_length=4000)

    question: str | None = Field(default=None, max_length=2000)
    business_context: str | None = Field(default=None, max_length=4000)


def require_text(value: str | None, field_name: str) -> str:
    if value is None or not value.strip():
        raise HTTPException(
            status_code=400,
            detail=f"{field_name} is required",
        )

    return value.strip()


@router.post("/generate")
def generate_ai_content(
    payload: AiGenerateRequest,
    user=Depends(get_logged_in_user),
):
    if payload.type == "product_description":
        prompt = build_product_description_prompt(
            product_name=require_text(payload.product_name, "Product name"),
            category=payload.category,
            price=payload.price,
            features=payload.features,
            audience=payload.audience,
        )

    elif payload.type == "instagram_caption":
        prompt = build_instagram_caption_prompt(
            product_name=require_text(payload.product_name, "Product name"),
            offer=payload.offer,
            audience=payload.audience,
            tone=payload.tone,
        )

    elif payload.type == "customer_reply":
        prompt = build_customer_reply_prompt(
            customer_message=require_text(
                payload.customer_message,
                "Customer message",
            ),
            product_context=payload.product_context,
            reply_tone=payload.tone,
        )

    elif payload.type == "sales_analysis":
        prompt = build_sales_analysis_prompt(
            summary=require_text(payload.summary, "Sales summary"),
        )

    elif payload.type == "inventory_advice":
        prompt = build_inventory_advice_prompt(
            inventory_summary=require_text(
                payload.inventory_summary,
                "Inventory summary",
            ),
        )

    else:
        prompt = build_general_chat_prompt(
            question=require_text(payload.question, "Question"),
            business_context=payload.business_context,
        )

    result = generate_ai_text(prompt)

    return {
        "success": True,
        "type": payload.type,
        "result": result,
    }