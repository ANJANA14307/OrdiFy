from fastapi import APIRouter, Depends, HTTPException

from core.auth import get_logged_in_user
from core.supabase import supabase
from schemas.delivery_fee import DeliveryQuoteRequest, DeliverySettingsUpdate


router = APIRouter(prefix="/delivery-fees", tags=["Delivery Fees"])


def _business_id(user) -> str:
    user_id = getattr(user, "id", None)
    if user_id:
        return str(user_id)
    if isinstance(user, dict) and user.get("id"):
        return str(user["id"])
    raise HTTPException(status_code=401, detail="Invalid user")


def _fetch_settings(business_id: str) -> dict | None:
    response = (
        supabase.table("delivery_settings")
        .select("*")
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None


@router.get("/settings")
def get_delivery_settings(user=Depends(get_logged_in_user)):
    settings = _fetch_settings(_business_id(user))
    return {"settings": settings}


@router.put("/settings")
def save_delivery_settings(
    payload: DeliverySettingsUpdate,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    settings_data = {
        **payload.model_dump(),
        "business_id": business_id,
    }

    try:
        response = (
            supabase.table("delivery_settings")
            .upsert(settings_data, on_conflict="business_id")
            .select()
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Delivery settings could not be saved: {error}",
        ) from error

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Delivery settings could not be saved",
        )
    return {"settings": response.data[0]}


def calculate_delivery_quote(settings: dict, pincode: str, subtotal: float) -> dict:
    rule_type = settings.get("rule_type")
    fee = 0.0
    estimated_delivery_days = None

    if rule_type == "flat_fee":
        fee = float(settings.get("flat_fee") or 0)
    elif rule_type == "free_above_minimum":
        threshold = float(settings.get("free_delivery_threshold") or 0)
        if subtotal < threshold:
            fee = float(settings.get("flat_fee") or 0)
    elif rule_type == "pincode_zone":
        matched_zone = next(
            (
                zone
                for zone in settings.get("zones") or []
                if pincode in zone.get("pincodes", [])
            ),
            None,
        )
        if matched_zone is None:
            return {
                "is_deliverable": False,
                "pincode": pincode,
                "subtotal": subtotal,
                "delivery_fee": 0.0,
                "tax": 0.0,
                "discount": 0.0,
                "total": subtotal,
                "estimated_delivery_days": None,
                "message": "Delivery is not available for this pincode",
            }
        fee = float(matched_zone.get("fee") or 0)
        estimated_delivery_days = matched_zone.get("estimated_delivery_days")
    else:
        raise HTTPException(status_code=500, detail="Invalid saved delivery rule")

    return {
        "is_deliverable": True,
        "pincode": pincode,
        "subtotal": subtotal,
        "delivery_fee": fee,
        "tax": 0.0,
        "discount": 0.0,
        "total": subtotal + fee,
        "estimated_delivery_days": estimated_delivery_days,
        "message": None,
    }


@router.post("/quote")
def quote_delivery(
    payload: DeliveryQuoteRequest,
    user=Depends(get_logged_in_user),
):
    settings = _fetch_settings(_business_id(user))
    if settings is None:
        raise HTTPException(
            status_code=404,
            detail="Delivery charges have not been configured",
        )
    return calculate_delivery_quote(settings, payload.pincode, payload.subtotal)
