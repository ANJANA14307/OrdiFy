import re
from typing import Literal

from pydantic import BaseModel, Field, field_validator


class WhatsAppConfigUpdate(BaseModel):
    phone_number: str = Field(min_length=8, max_length=24)
    phone_number_id: str = Field(min_length=1, max_length=100)
    is_enabled: bool = False

    @field_validator("phone_number")
    @classmethod
    def validate_phone_number(cls, value: str) -> str:
        cleaned = value.strip()
        if not re.fullmatch(r"\+[1-9]\d{7,14}", cleaned):
            raise ValueError("Use an international phone number, such as +919876543210")
        return cleaned

    @field_validator("phone_number_id")
    @classmethod
    def normalize_phone_number_id(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("WhatsApp Cloud API phone number ID is required")
        return cleaned


class MessageTemplatesUpdate(BaseModel):
    confirmation: str = Field(min_length=1, max_length=1000)
    shipped: str = Field(min_length=1, max_length=1000)
    delivered: str = Field(min_length=1, max_length=1000)


class SocialOrderAction(BaseModel):
    action: Literal["confirm_manually", "reject", "ask_edit"]
    customer_confirmed: bool = False
