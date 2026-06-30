from datetime import datetime, timezone
from typing import Any, Optional
import json

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel

from core.auth import get_logged_in_user
from core.config import settings
from core.supabase import supabase


router = APIRouter(prefix="/payments", tags=["Payments"])


class OrderPaymentRequest(BaseModel):
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


def fetch_order_for_user(order_id: str, user_id: str):
    response = (
        supabase.table("orders")
        .select("*")
        .eq("id", order_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not response.data:
        raise HTTPException(status_code=404, detail="Order not found")

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


def get_latest_payment(order_id: str, user_id: str, gateway: Optional[str] = None):
    query = (
        supabase.table("payments")
        .select("*")
        .eq("order_id", order_id)
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(1)
    )

    if gateway:
        query = query.eq("gateway", gateway)

    response = query.execute()

    if not response.data:
        return None

    return response.data[0]


def get_payment_for_user(payment_id: str, user_id: str):
    response = (
        supabase.table("payments")
        .select("*")
        .eq("id", payment_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not response.data:
        raise HTTPException(status_code=404, detail="Payment not found")

    return response.data[0]


def create_payment_row(
    order: dict[str, Any],
    gateway: str,
    gateway_payment_id: str,
    amount: float,
    currency: str,
    status: str,
    payment_link_url: Optional[str] = None,
):
    response = (
        supabase.table("payments")
        .insert(
            {
                "order_id": order["id"],
                "user_id": order["user_id"],
                "gateway": gateway,
                "gateway_payment_id": gateway_payment_id,
                "amount": amount,
                "currency": currency,
                "status": status,
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


def update_payment_status(
    payment_id: str,
    status: str,
    paid_at: Optional[str] = None,
):
    update_data = {"status": status}

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
            .update({"stock_count": new_stock})
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

    update_data = {"stock_processed": True}

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


def get_razorpay_client():
    if not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
        raise HTTPException(
            status_code=500,
            detail="Razorpay keys are not configured in .env yet",
        )

    try:
        import razorpay
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Razorpay SDK is not installed. Run: pip install razorpay",
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
            detail="RAZORPAY_WEBHOOK_SECRET is not configured in .env yet",
        )

    return settings.RAZORPAY_WEBHOOK_SECRET


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
    return text if text else None


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
                "supports": ["UPI", "Cards", "Netbanking", "Wallets"],
            },
            "cod": {
                "enabled": True,
                "label": "Cash on Delivery",
                "currency": "INR",
                "supports": ["Manual collection", "Pay later"],
            },
            "stripe": {
                "enabled": False,
                "label": "Stripe",
                "currency": "Global",
                "supports": [],
            },
        }
    }


@router.get("/order/{order_id}")
def get_order_payments(
    order_id: str,
    user=Depends(get_logged_in_user),
):
    order = fetch_order_for_user(order_id=order_id, user_id=user.id)

    response = (
        supabase.table("payments")
        .select("*")
        .eq("order_id", order_id)
        .eq("user_id", user.id)
        .order("created_at", desc=True)
        .execute()
    )

    payments = response.data or []
    latest_payment = payments[0] if payments else None

    return {
        "order": {
            "id": order["id"],
            "order_number": order.get("order_number"),
            "status": order.get("status"),
            "total_amount": order.get("total_amount"),
        },
        "latest_payment": latest_payment,
        "payments": payments,
        "count": len(payments),
    }


@router.post("/cod/create")
def create_cod_payment(
    payload: OrderPaymentRequest,
    user=Depends(get_logged_in_user),
):
    order = fetch_order_for_user(order_id=payload.order_id, user_id=user.id)

    if order.get("status") == "cancelled":
        raise HTTPException(
            status_code=400,
            detail="Cannot create COD payment for a cancelled order",
        )

    amount = to_float(order.get("total_amount"))

    if amount <= 0:
        raise HTTPException(
            status_code=400,
            detail="Order amount must be greater than zero",
        )

    existing_payment = get_latest_payment(
        order_id=order["id"],
        user_id=user.id,
        gateway="cod",
    )

    if existing_payment:
        return {
            "message": "Existing COD payment returned",
            "payment": existing_payment,
            "order": order,
        }

    payment = create_payment_row(
        order=order,
        gateway="cod",
        gateway_payment_id=f"cod_{order['id']}_{int(datetime.now().timestamp())}",
        amount=amount,
        currency="INR",
        status="pending",
        payment_link_url=None,
    )

    return {
        "message": "COD payment created successfully",
        "payment": payment,
        "order": order,
    }


@router.patch("/{payment_id}/mark-paid")
def mark_payment_as_paid(
    payment_id: str,
    user=Depends(get_logged_in_user),
):
    payment = get_payment_for_user(payment_id=payment_id, user_id=user.id)

    if payment.get("status") == "paid":
        return {
            "message": "Payment is already marked as paid",
            "payment": payment,
        }

    if payment.get("status") == "failed":
        raise HTTPException(
            status_code=400,
            detail="Failed payment cannot be marked as paid. Create a new payment.",
        )

    updated_payment = update_payment_status(
        payment_id=payment["id"],
        status="paid",
        paid_at=now_iso(),
    )

    updated_order = confirm_order_after_payment(payment["order_id"])

    return {
        "message": "Payment marked as paid successfully",
        "payment": updated_payment,
        "order": updated_order,
    }


@router.post("/razorpay/create-link")
def create_razorpay_payment_link(
    payload: OrderPaymentRequest,
    user=Depends(get_logged_in_user),
):
    client = get_razorpay_client()

    order = fetch_order_for_user(order_id=payload.order_id, user_id=user.id)

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

    existing_payment = get_latest_payment(
        order_id=order["id"],
        user_id=user.id,
        gateway="razorpay",
    )

    if existing_payment:
        if existing_payment.get("status") == "paid":
            return {
                "message": "Order is already paid",
                "payment": existing_payment,
                "order": order,
            }

        if existing_payment.get("payment_link_url"):
            return {
                "message": "Existing Razorpay payment link returned",
                "payment_link_url": existing_payment.get("payment_link_url"),
                "short_url": existing_payment.get("payment_link_url"),
                "payment": existing_payment,
                "order": order,
            }

    customer = fetch_customer(order.get("customer_id"))
    customer_data = {}

    if customer:
        customer_name = (
            customer.get("display_name")
            or customer.get("instagram_username")
            or ""
        )
        customer_email = customer.get("email") or ""
        customer_phone = customer.get("phone") or ""

        if customer_name:
            customer_data["name"] = customer_name
        if customer_email:
            customer_data["email"] = customer_email
        if customer_phone:
            customer_data["contact"] = customer_phone

    order_number = order.get("order_number") or order["id"]
    amount_in_paise = int(round(amount * 100))

    payment_link_payload = {
        "amount": amount_in_paise,
        "currency": "INR",
        "accept_partial": False,
        "description": f"Payment for OrdiFy Order {order_number}",
        "notify": {"sms": False, "email": False},
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

    if customer_data:
        payment_link_payload["customer"] = customer_data

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
        gateway="razorpay",
        gateway_payment_id=payment_link_id,
        amount=amount,
        currency="INR",
        status="pending",
        payment_link_url=payment_link_url,
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
        event_payload = json.loads(raw_body.decode("utf-8"))
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
        order_id = extract_order_id_from_notes(payment_link_entity.get("notes"))

    if not order_id and payment_entity:
        order_id = extract_order_id_from_notes(payment_entity.get("notes"))

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
            update_payment_status(payment_id=payment["id"], status="failed")

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