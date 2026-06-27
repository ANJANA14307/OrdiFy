from datetime import datetime, timezone
from typing import Any, Optional

import razorpay
from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel

from core.auth import get_logged_in_user
from core.config import settings
from core.supabase import supabase


router = APIRouter(prefix="/payments", tags=["Payments"])


class RazorpayCreateLinkRequest(BaseModel):
    order_id: str


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def to_float(value: Any) -> float:
    if value is None:
        return 0.0

    try:
        return float(value)
    except Exception:
        return 0.0


def to_int(value: Any) -> int:
    if value is None:
        return 0

    try:
        return int(value)
    except Exception:
        return 0


def get_razorpay_client():
    if not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
        raise HTTPException(
            status_code=500,
            detail="Razorpay keys are not configured in .env",
        )

    return razorpay.Client(
        auth=(
            settings.RAZORPAY_KEY_ID,
            settings.RAZORPAY_KEY_SECRET,
        )
    )


def require_razorpay_webhook_secret() -> str:
    if not settings.RAZORPAY_WEBHOOK_SECRET:
        raise HTTPException(
            status_code=500,
            detail="RAZORPAY_WEBHOOK_SECRET is not configured in .env",
        )

    return settings.RAZORPAY_WEBHOOK_SECRET


def fetch_order_for_user(order_id: str, user_id: str):
    response = (
        supabase.table("orders")
        .select("*")
        .eq("id", order_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail="Order not found",
        )

    return response.data[0]


def fetch_order_any_user(order_id: str):
    response = (
        supabase.table("orders")
        .select("*")
        .eq("id", order_id)
        .execute()
    )

    if not response.data:
        return None

    return response.data[0]


def fetch_customer(customer_id: Optional[str]):
    if not customer_id:
        return None

    response = (
        supabase.table("customers")
        .select("*")
        .eq("id", customer_id)
        .execute()
    )

    if not response.data:
        return None

    return response.data[0]


def fetch_order_items(order_id: str):
    response = (
        supabase.table("order_items")
        .select("*")
        .eq("order_id", order_id)
        .execute()
    )

    return response.data or []


def get_existing_razorpay_payment(order_id: str, user_id: str):
    response = (
        supabase.table("payments")
        .select("*")
        .eq("order_id", order_id)
        .eq("user_id", user_id)
        .eq("gateway", "razorpay")
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )

    if not response.data:
        return None

    return response.data[0]


def create_payment_row(
    order: dict[str, Any],
    payment_link_id: str,
    payment_link_url: str,
    amount: float,
):
    response = (
        supabase.table("payments")
        .insert(
            {
                "order_id": order["id"],
                "user_id": order["user_id"],
                "gateway": "razorpay",
                "gateway_payment_id": payment_link_id,
                "amount": amount,
                "currency": "INR",
                "status": "pending",
                "payment_link_url": payment_link_url,
            }
        )
        .execute()
    )

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Payment row could not be created",
        )

    return response.data[0]


def find_payment_for_webhook(
    order_id: Optional[str] = None,
    payment_link_id: Optional[str] = None,
):
    query = (
        supabase.table("payments")
        .select("*")
        .eq("gateway", "razorpay")
        .order("created_at", desc=True)
        .limit(1)
    )

    if payment_link_id:
        query = query.eq("gateway_payment_id", payment_link_id)
    elif order_id:
        query = query.eq("order_id", order_id)
    else:
        return None

    response = query.execute()

    if not response.data:
        return None

    return response.data[0]


def update_payment_status(
    payment_id: str,
    status: str,
    paid_at: Optional[str] = None,
):
    update_data = {
        "status": status,
    }

    if paid_at:
        update_data["paid_at"] = paid_at

    response = (
        supabase.table("payments")
        .update(update_data)
        .eq("id", payment_id)
        .execute()
    )

    if not response.data:
        return None

    return response.data[0]


def decrement_stock_for_paid_order(order: dict[str, Any]):
    if order.get("stock_processed") is True:
        return

    order_items = fetch_order_items(order["id"])

    for item in order_items:
        product_id = item.get("product_id")
        quantity = to_int(item.get("quantity"))

        if not product_id or quantity <= 0:
            continue

        product_response = (
            supabase.table("products")
            .select("id, stock_count")
            .eq("id", product_id)
            .eq("user_id", order["user_id"])
            .execute()
        )

        if not product_response.data:
            continue

        product = product_response.data[0]
        current_stock = to_int(product.get("stock_count"))
        new_stock = max(0, current_stock - quantity)

        (
            supabase.table("products")
            .update(
                {
                    "stock_count": new_stock,
                }
            )
            .eq("id", product_id)
            .eq("user_id", order["user_id"])
            .execute()
        )


def confirm_order_after_payment(order_id: str):
    order = fetch_order_any_user(order_id)

    if not order:
        return None

    current_status = order.get("status")

    if current_status == "cancelled":
        return order

    decrement_stock_for_paid_order(order)

    update_data = {
        "stock_processed": True,
    }

    if current_status == "new":
        update_data["status"] = "confirmed"
        update_data["confirmed_at"] = now_iso()

    response = (
        supabase.table("orders")
        .update(update_data)
        .eq("id", order_id)
        .execute()
    )

    if not response.data:
        return order

    return response.data[0]


def extract_order_id_from_notes(notes: Any) -> Optional[str]:
    if not notes:
        return None

    try:
        value = notes.get("order_id")
    except Exception:
        return None

    if value is None:
        return None

    text = str(value).strip()

    if not text:
        return None

    return text


def get_entity(payload: dict[str, Any], entity_name: str):
    return (
        payload.get("payload", {})
        .get(entity_name, {})
        .get("entity")
    )


@router.get("/gateways")
def get_payment_gateways():
    razorpay_configured = bool(
        settings.RAZORPAY_KEY_ID and settings.RAZORPAY_KEY_SECRET
    )

    return {
        "gateways": {
            "razorpay": {
                "enabled": razorpay_configured,
                "label": "Razorpay",
                "currency": "INR",
                "supports": [
                    "UPI",
                    "Cards",
                    "Netbanking",
                    "Wallets",
                ],
            },
            "cod": {
                "enabled": True,
                "label": "Cash on Delivery",
                "currency": "INR",
                "supports": [
                    "Manual collection",
                ],
            },
            "stripe": {
                "enabled": False,
                "label": "Stripe",
                "currency": "Global",
                "supports": [],
            },
        }
    }


@router.post("/razorpay/create-link")
def create_razorpay_payment_link(
    payload: RazorpayCreateLinkRequest,
    user=Depends(get_logged_in_user),
):
    client = get_razorpay_client()

    order = fetch_order_for_user(
        order_id=payload.order_id,
        user_id=user.id,
    )

    if order.get("status") == "cancelled":
        raise HTTPException(
            status_code=400,
            detail="Cannot create payment link for a cancelled order",
        )

    amount = to_float(order.get("total_amount"))

    if amount <= 0:
        raise HTTPException(
            status_code=400,
            detail="Order amount must be greater than zero",
        )

    existing_payment = get_existing_razorpay_payment(
        order_id=order["id"],
        user_id=user.id,
    )

    if existing_payment:
        if existing_payment.get("status") == "paid":
            return {
                "message": "Order is already paid",
                "payment": existing_payment,
            }

        if existing_payment.get("payment_link_url"):
            return {
                "message": "Existing Razorpay payment link returned",
                "payment_link_url": existing_payment.get("payment_link_url"),
                "short_url": existing_payment.get("payment_link_url"),
                "payment": existing_payment,
            }

    customer = fetch_customer(order.get("customer_id"))

    customer_name = "OrdiFy Customer"
    customer_email = ""
    customer_phone = ""

    if customer:
        customer_name = (
            customer.get("display_name")
            or customer.get("instagram_username")
            or "OrdiFy Customer"
        )
        customer_email = customer.get("email") or ""
        customer_phone = customer.get("phone") or ""

    order_number = order.get("order_number") or order["id"]
    amount_in_paise = int(round(amount * 100))

    payment_link_payload = {
        "amount": amount_in_paise,
        "currency": "INR",
        "accept_partial": False,
        "description": f"Payment for OrdiFy Order {order_number}",
        "customer": {
            "name": customer_name,
            "email": customer_email,
            "contact": customer_phone,
        },
        "notify": {
            "sms": False,
            "email": False,
        },
        "reminder_enable": True,
        "notes": {
            "order_id": order["id"],
            "user_id": user.id,
            "order_number": str(order_number),
            "source": "ordify",
        },
        "callback_url": settings.RAZORPAY_CALLBACK_URL,
        "callback_method": "get",
    }

    try:
        payment_link = client.payment_link.create(payment_link_payload)
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Razorpay payment link creation failed: {str(error)}",
        )

    payment_link_id = payment_link.get("id")
    payment_link_url = payment_link.get("short_url") or payment_link.get("url")

    if not payment_link_id or not payment_link_url:
        raise HTTPException(
            status_code=500,
            detail="Razorpay did not return a valid payment link",
        )

    payment = create_payment_row(
        order=order,
        payment_link_id=payment_link_id,
        payment_link_url=payment_link_url,
        amount=amount,
    )

    return {
        "message": "Razorpay payment link created successfully",
        "payment_link_url": payment_link_url,
        "short_url": payment_link_url,
        "payment": payment,
        "razorpay_payment_link": payment_link,
        "order": {
            "id": order["id"],
            "order_number": order_number,
            "total_amount": amount,
            "status": order.get("status"),
        },
    }


@router.post("/razorpay/webhook")
async def razorpay_webhook(
    request: Request,
    razorpay_signature: str | None = Header(
        default=None,
        alias="X-Razorpay-Signature",
    ),
):
    client = get_razorpay_client()
    webhook_secret = require_razorpay_webhook_secret()

    raw_body = await request.body()

    if not razorpay_signature:
        raise HTTPException(
            status_code=400,
            detail="Missing X-Razorpay-Signature header",
        )

    try:
        client.utility.verify_webhook_signature(
            raw_body.decode("utf-8"),
            razorpay_signature,
            webhook_secret,
        )
    except Exception:
        raise HTTPException(
            status_code=400,
            detail="Invalid Razorpay webhook signature",
        )

    try:
        event_payload = await request.json()
    except Exception:
        raise HTTPException(
            status_code=400,
            detail="Invalid webhook JSON payload",
        )

    event_name = event_payload.get("event")

    payment_link_entity = get_entity(event_payload, "payment_link")
    payment_entity = get_entity(event_payload, "payment")

    payment_link_id = None
    order_id = None

    if payment_link_entity:
        payment_link_id = payment_link_entity.get("id")
        order_id = extract_order_id_from_notes(
            payment_link_entity.get("notes")
        )

    if not order_id and payment_entity:
        order_id = extract_order_id_from_notes(
            payment_entity.get("notes")
        )

    if event_name == "payment_link.paid":
        payment = find_payment_for_webhook(
            order_id=order_id,
            payment_link_id=payment_link_id,
        )

        if payment:
            update_payment_status(
                payment_id=payment["id"],
                status="paid",
                paid_at=now_iso(),
            )

            confirm_order_after_payment(payment["order_id"])

        return {
            "received": True,
            "event": event_name,
            "payment_updated": payment is not None,
            "order_id": order_id,
            "payment_link_id": payment_link_id,
        }

    if event_name in ["payment.failed", "payment_link.cancelled"]:
        payment = find_payment_for_webhook(
            order_id=order_id,
            payment_link_id=payment_link_id,
        )

        if payment:
            update_payment_status(
                payment_id=payment["id"],
                status="failed",
            )

        return {
            "received": True,
            "event": event_name,
            "payment_updated": payment is not None,
            "order_id": order_id,
            "payment_link_id": payment_link_id,
        }

    return {
        "received": True,
        "event": event_name,
        "handled": False,
    }