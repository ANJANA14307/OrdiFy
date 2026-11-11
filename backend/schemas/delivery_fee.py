import re
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator, model_validator


DeliveryRuleType = Literal["flat_fee", "free_above_minimum", "pincode_zone"]
PINCODE_PATTERN = re.compile(r"^\d{6}$")


class DeliveryZone(BaseModel):
    name: str = Field(..., min_length=1, max_length=80)
    pincodes: list[str] = Field(..., min_length=1)
    fee: float = Field(..., ge=0)
    estimated_delivery_days: int = Field(..., ge=1, le=90)

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Zone name is required")
        return cleaned

    @field_validator("pincodes")
    @classmethod
    def validate_pincodes(cls, values: list[str]) -> list[str]:
        normalized = list(dict.fromkeys(value.strip() for value in values))
        invalid = [value for value in normalized if not PINCODE_PATTERN.fullmatch(value)]
        if invalid:
            raise ValueError(f"Invalid pincode: {invalid[0]}")
        return normalized


class DeliverySettingsUpdate(BaseModel):
    rule_type: DeliveryRuleType
    flat_fee: float = Field(default=0, ge=0)
    free_delivery_threshold: Optional[float] = Field(default=None, ge=0)
    zones: list[DeliveryZone] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_rule_settings(self):
        if self.rule_type == "free_above_minimum" and self.free_delivery_threshold is None:
            raise ValueError("Minimum order amount is required for free delivery")

        seen_pincodes: set[str] = set()
        for zone in self.zones:
            overlap = seen_pincodes.intersection(zone.pincodes)
            if overlap:
                raise ValueError(
                    f"Pincode {next(iter(overlap))} is assigned to more than one zone"
                )
            seen_pincodes.update(zone.pincodes)

        if self.rule_type == "pincode_zone" and not self.zones:
            raise ValueError("Add at least one delivery zone")

        return self


class DeliveryQuoteRequest(BaseModel):
    pincode: str = Field(..., min_length=6, max_length=6)
    subtotal: float = Field(..., ge=0)

    @field_validator("pincode")
    @classmethod
    def validate_pincode(cls, value: str) -> str:
        cleaned = value.strip()
        if not PINCODE_PATTERN.fullmatch(cleaned):
            raise ValueError("Pincode must be exactly 6 digits")
        return cleaned
