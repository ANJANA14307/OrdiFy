from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator


ReturnReason = Literal[
    "damaged",
    "wrong_item",
    "not_as_described",
    "size_or_fit",
    "changed_mind",
    "other",
]
ReturnOutcome = Literal["refund", "exchange"]
ReturnStatus = Literal[
    "return_requested",
    "approved",
    "item_received",
    "inspected",
    "refund_issued",
    "exchange_created",
    "rejected",
]
InspectionResult = Literal["accepted", "partially_accepted", "rejected"]


class ReturnPolicyUpdate(BaseModel):
    return_window_days: int = Field(ge=1, le=365)
    eligible_conditions: list[str] = Field(default_factory=list, max_length=20)
    non_returnable_product_ids: list[str] = Field(default_factory=list, max_length=500)
    allow_refund: bool = True
    allow_exchange: bool = True
    policy_text: str = Field(min_length=1, max_length=4000)

    @field_validator("eligible_conditions")
    @classmethod
    def normalize_conditions(cls, values: list[str]) -> list[str]:
        allowed = {
            "unused",
            "unworn",
            "original_packaging",
            "tags_attached",
            "proof_of_purchase",
        }
        normalized = list(dict.fromkeys(value.strip() for value in values))
        invalid = [value for value in normalized if value not in allowed]
        if invalid:
            raise ValueError(f"Unsupported return condition: {invalid[0]}")
        return normalized

    @field_validator("non_returnable_product_ids")
    @classmethod
    def normalize_product_ids(cls, values: list[str]) -> list[str]:
        normalized = []
        for value in values:
            try:
                normalized.append(str(UUID(value)))
            except ValueError as error:
                raise ValueError("Non-returnable product IDs must be valid UUIDs") from error
        return list(dict.fromkeys(normalized))

    @field_validator("policy_text")
    @classmethod
    def clean_policy_text(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Return policy text is required")
        return cleaned

    @model_validator(mode="after")
    def validate_outcomes(self):
        if not self.allow_refund and not self.allow_exchange:
            raise ValueError("Enable at least one return outcome")
        return self


class ReturnItemRequest(BaseModel):
    order_item_id: str = Field(min_length=1)
    quantity: int = Field(ge=1)


class ReturnRequestCreate(BaseModel):
    items: list[ReturnItemRequest] = Field(min_length=1, max_length=100)
    reason: ReturnReason
    comment: str | None = Field(default=None, max_length=2000)
    photos: list[str] = Field(default_factory=list, max_length=5)
    preferred_outcome: ReturnOutcome

    @field_validator("photos")
    @classmethod
    def validate_photos(cls, values: list[str]) -> list[str]:
        normalized = list(dict.fromkeys(value.strip() for value in values if value.strip()))
        if any(len(value) > 2048 or not value.startswith("https://") for value in normalized):
            raise ValueError("Return photos must be secure uploaded image URLs")
        return normalized


class InspectionItem(BaseModel):
    order_item_id: str = Field(min_length=1)
    accepted_quantity: int = Field(ge=0)


class ReturnAction(BaseModel):
    action: Literal[
        "approve",
        "reject",
        "mark_received",
        "inspect",
        "issue_refund",
        "create_exchange",
    ]
    reason: str | None = Field(default=None, max_length=1000)
    inspection_result: InspectionResult | None = None
    inspected_items: list[InspectionItem] = Field(default_factory=list, max_length=100)
    notes: str | None = Field(default=None, max_length=2000)
    photos: list[str] = Field(default_factory=list, max_length=5)
    refund_amount: float | None = Field(default=None, ge=0)

    @field_validator("photos")
    @classmethod
    def validate_photos(cls, values: list[str]) -> list[str]:
        normalized = list(dict.fromkeys(value.strip() for value in values if value.strip()))
        if any(len(value) > 2048 or not value.startswith("https://") for value in normalized):
            raise ValueError("Inspection photos must be secure uploaded image URLs")
        return normalized

    @model_validator(mode="after")
    def validate_action_fields(self):
        if self.action == "inspect":
            if self.inspection_result is None:
                raise ValueError("Inspection result is required")
            if not self.inspected_items:
                raise ValueError("Enter inspection quantities for the returned items")
        if self.action == "issue_refund" and self.refund_amount is None:
            raise ValueError("Refund amount is required")
        return self
