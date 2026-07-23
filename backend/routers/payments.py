from datetime import datetime, timezone
from typing import Any
import hashlib
import hmac
import json
import time

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel

from core.auth import get_logged_in_user
from core.config import settings
from core.supabase import supabase
from services.activity_service import create_activity_log
from services.invoice_service import generate_invoice_for_payment
from services.notification_service import create_notification

try:
    import razorpay
except Exception:
    razorpay = None


router = APIRouter(prefix="/payments", tags=["Payments"])


class CODCreateRequest(BaseModel):
    order_id: str


class RazorpayCreateLinkRequest(BaseModel):
    order_id: str


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def user_id_from_user(user) -> str:
    return str(user.id)


def to_float(value: Any) -> float:
    try:
        return float(value or 0)
    except Exception:
        return 0.0


def to_int(value: Any) -> int:
    try:
        return int(value or 0)
    except Exception:
        return 0


def get_order_for_user(order_id: str, user_id: str) -> dict:
    response = (
        supabase.table("orders")
        .select("*")
        .eq("id", order_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )

    if not response.data:
        raise HTTPException(status_code=404, detail="Order not found")

    return response.data[0]


def get_payment_for_user(payment_id: str, user_id: str) -> dict:
    response = (
        supabase.table("payments")
        .select("*")
        .eq("id", payment_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )

    if not response.data:
        raise HTTPException(status_code=404, detail="Payment not found")

    return response.data[0]


def get_payments_for_order(order_id: str, user_id: str) -> list[dict]:
    get_order_for_user(order_id, user_id)

    response = (
        supabase.table("payments")
        .select("*")
        .eq("order_id", order_id)
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .execute()
    )

    return response.data or []


def get_paid_payment_for_order(
    order_id: str,
    user_id: str,
    exclude_payment_id: str | None = None,
):
    query = (
        supabase.table("payments")
        .select("*")
        .eq("order_id", order_id)
        .eq("user_id", user_id)
        .eq("status", "paid")
    )

    if exclude_payment_id:
        query = query.neq("id", exclude_payment_id)

    response = query.order("created_at", desc=True).limit(1).execute()

    if not response.data:
        return None

    return response.data[0]


def get_existing_payment_for_order(
    order_id: str,
    user_id: str,
    gateway: str | None = None,
    statuses: list[str] | None = None,
):
    query = (
        supabase.table("payments")
        .select("*")
        .eq("order_id", order_id)
        .eq("user_id", user_id)
    )

    if gateway:
        query = query.eq("gateway", gateway)

    if statuses:
        query = query.in_("status", statuses)

    response = query.order("created_at", desc=True).limit(1).execute()

    if not response.data:
        return None

    return response.data[0]


def get_order_items(order_id: str) -> list[dict]:
    response = (
        supabase.table("order_items")
        .select("*")
        .eq("order_id", order_id)
        .execute()
    )

    return response.data or []


def get_product_for_user(product_id: str, user_id: str):
    response = (
        supabase.table("products")
        .select("*")
        .eq("id", product_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )

    if not response.data:
        return None

    return response.data[0]


def create_payment_row(
    order_id: str,
    user_id: str,
    gateway: str,
    gateway_payment_id: str,
    amount: float,
    currency: str = "INR",
    status: str = "pending",
    payment_link_url: str | None = None,
):
    response = (
        supabase.table("payments")
        .insert(
            {
                "order_id": order_id,
                "user_id": user_id,
                "gateway": gateway,
                "gateway_payment_id": gateway_payment_id,
                "amount": amount,
                "currency": currency,
                "status": status,
                "payment_link_url": payment_link_url,
                "paid_at": None,
            }
        )
        .select()
        .execute()
    )

    if not response.data:
        raise HTTPException(status_code=500, detail="Payment could not be created")

    return response.data[0]


def update_payment_status(payment_id: str, status: str, paid_at: str | None = None):
    update_data = {"status": status}

    if paid_at is not None:
        update_data["paid_at"] = paid_at

    response = (
        supabase.table("payments")
        .update(update_data)
        .eq("id", payment_id)
        .select()
        .execute()
    )

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Payment status could not be updated",
        )

    return response.data[0]


def decrement_stock_for_new_order(order: dict, user_id: str) -> None:
    items = get_order_items(order["id"])

    if not items:
        raise HTTPException(status_code=400, detail="Order has no items")

    prepared_updates = []

    for item in items:
        product_id = str(item.get("product_id"))
        quantity = to_int(item.get("quantity"))

        if quantity <= 0:
            raise HTTPException(status_code=400, detail="Invalid order item quantity")

        product = get_product_for_user(product_id, user_id)

        if not product:
            raise HTTPException(status_code=404, detail="Product not found")

        current_stock = to_int(product.get("stock_count"))

        if current_stock < quantity:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Not enough stock for {product.get('name') or 'Product'}. "
                    f"Available: {current_stock}, required: {quantity}"
                ),
            )

        prepared_updates.append(
            {
                "product": product,
                "product_id": product_id,
                "old_stock": current_stock,
                "quantity": quantity,
                "new_stock": current_stock - quantity,
            }
        )

    for item in prepared_updates:
        (
            supabase.table("products")
            .update({"stock_count": item["new_stock"]})
            .eq("id", item["product_id"])
            .eq("user_id", user_id)
            .execute()
        )

        create_activity_log(
            user_id=user_id,
            action="stock_decremented",
            description=(
                f"Stock reduced for {item['product'].get('name') or 'Product'} "
                "after payment."
            ),
            entity_type="product",
            entity_id=item["product_id"],
            metadata={
                "order_id": order["id"],
                "old_stock": item["old_stock"],
                "quantity_sold": item["quantity"],
                "new_stock": item["new_stock"],
            },
        )

        threshold = to_int(item["product"].get("low_stock_threshold")) or 5

        if item["new_stock"] <= threshold:
            create_notification(
                user_id=user_id,
                title="Low stock alert",
                message=(
                    f"{item['product'].get('name') or 'Product'} is low on stock. "
                    f"Only {item['new_stock']} left."
                ),
                notification_type="warning",
                entity_type="product",
                entity_id=item["product_id"],
            )


def confirm_order_after_payment(order_id: str, user_id: str) -> dict:
    order = get_order_for_user(order_id, user_id)
    current_status = order.get("status") or "new"

    if current_status == "cancelled":
        raise HTTPException(
            status_code=400,
            detail="Cancelled order cannot be marked paid",
        )

    if current_status == "new":
        decrement_stock_for_new_order(order, user_id)

        response = (
            supabase.table("orders")
            .update(
                {
                    "status": "confirmed",
                    "updated_at": now_iso(),
                }
            )
            .eq("id", order_id)
            .eq("user_id", user_id)
            .select()
            .execute()
        )

        if not response.data:
            raise HTTPException(
                status_code=500,
                detail="Order could not be confirmed after payment",
            )

        return response.data[0]

    return order


def refresh_customer_stats(customer_id: str | None, user_id: str) -> None:
    if not customer_id:
        return

    try:
        orders_response = (
            supabase.table("orders")
            .select("id,total_amount,status")
            .eq("customer_id", customer_id)
            .eq("user_id", user_id)
            .neq("status", "cancelled")
            .execute()
        )

        orders = orders_response.data or []

        total_orders = len(orders)
        total_spent = sum(to_float(order.get("total_amount")) for order in orders)

        (
            supabase.table("customers")
            .update(
                {
                    "total_orders": total_orders,
                    "total_spent": total_spent,
                }
            )
            .eq("id", customer_id)
            .eq("user_id", user_id)
            .execute()
        )
    except Exception:
        pass


def safely_generate_invoice_after_payment(payment: dict[str, Any]):
    try:
        return generate_invoice_for_payment(
            payment_id=payment["id"],
            user_id=payment["user_id"],
        )
    except Exception as error:
        return {
            "message": "Payment succeeded, but invoice auto-generation failed",
            "error": str(error),
        }


def create_payment_success_notification(payment: dict, order: dict) -> None:
    order_number = order.get("order_number") or order.get("id")
    amount = to_float(payment.get("amount"))

    create_notification(
        user_id=payment["user_id"],
        title="Payment received",
        message=f"Payment of Rs. {amount:.2f} received for order {order_number}.",
        notification_type="success",
        entity_type="order",
        entity_id=order["id"],
    )


def get_razorpay_client():
    if razorpay is None:
        raise HTTPException(
            status_code=400,
            detail="Razorpay package is not installed. Run: pip install razorpay",
        )

    if not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
        raise HTTPException(
            status_code=400,
            detail="Razorpay is not configured yet. Add Razorpay keys in backend .env.",
        )

    return razorpay.Client(
        auth=(
            settings.RAZORPAY_KEY_ID,
            settings.RAZORPAY_KEY_SECRET,
        )
    )


def verify_razorpay_webhook_signature(body: bytes, signature: str | None):
    if not settings.RAZORPAY_WEBHOOK_SECRET:
        raise HTTPException(
            status_code=400,
            detail="Razorpay webhook secret is not configured",
        )

    if not signature:
        raise HTTPException(
            status_code=400,
            detail="Missing Razorpay webhook signature",
        )

    expected_signature = hmac.new(
        settings.RAZORPAY_WEBHOOK_SECRET.encode(),
        body,
        hashlib.sha256,
    ).hexdigest()

    if not hmac.compare_digest(expected_signature, signature):
        raise HTTPException(
            status_code=400,
            detail="Invalid Razorpay webhook signature",
        )


def find_payment_by_gateway_payment_id(gateway_payment_id: str):
    response = (
        supabase.table("payments")
        .select("*")
        .eq("gateway_payment_id", gateway_payment_id)
        .limit(1)
        .execute()
    )

    if not response.data:
        return None

    return response.data[0]


@router.get("/gateways")
def get_payment_gateways(user=Depends(get_logged_in_user)):
    razorpay_enabled = bool(
        razorpay is not None
        and settings.RAZORPAY_KEY_ID
        and settings.RAZORPAY_KEY_SECRET
    )

    return {
        "gateways": {
            "cod": {
                "enabled": True,
                "label": "Cash / Manual Payment",
                "description": "Use this for COD, UPI received manually, or testing.",
            },
            "razorpay": {
                "enabled": razorpay_enabled,
                "label": "Razorpay",
                "description": "Online payment links through Razorpay.",
                "key_id": settings.RAZORPAY_KEY_ID if razorpay_enabled else None,
            },
        }
    }


@router.get("/order/{order_id}")
def get_payments_for_single_order(
    order_id: str,
    user=Depends(get_logged_in_user),
):
    user_id = user_id_from_user(user)

    payments = get_payments_for_order(order_id, user_id)
    paid_payment = get_paid_payment_for_order(order_id, user_id)
    latest_payment = payments[0] if payments else None

    return {
        "payments": payments,
        "count": len(payments),
        "latest_payment": latest_payment,
        "paid_payment": paid_payment,
        "has_paid_payment": paid_payment is not None,
    }


@router.post("/cod/create")
def create_cod_payment(
    payload: CODCreateRequest,
    user=Depends(get_logged_in_user),
):
    user_id = user_id_from_user(user)
    order = get_order_for_user(payload.order_id, user_id)

    if order.get("status") == "cancelled":
        raise HTTPException(
            status_code=400,
            detail="Cannot create payment for a cancelled order",
        )

    amount = to_float(order.get("total_amount"))

    if amount <= 0:
        raise HTTPException(status_code=400, detail="Order amount must be greater than 0")

    paid_payment = get_paid_payment_for_order(order["id"], user_id)

    if paid_payment:
        return {
            "message": "This order already has a paid payment.",
            "payment": paid_payment,
            "order": order,
            "duplicate_prevented": True,
        }

    existing_cod_payment = get_existing_payment_for_order(
        order_id=order["id"],
        user_id=user_id,
        gateway="cod",
        statuses=["pending", "paid"],
    )

    if existing_cod_payment:
        return {
            "message": "COD payment already exists for this order.",
            "payment": existing_cod_payment,
            "order": order,
            "duplicate_prevented": True,
        }

    payment = create_payment_row(
        order_id=order["id"],
        user_id=user_id,
        gateway="cod",
        gateway_payment_id=f"cod_{order['id']}_{int(time.time())}",
        amount=amount,
        currency="INR",
        status="pending",
        payment_link_url=None,
    )

    create_activity_log(
        user_id=user_id,
        action="payment_created",
        description="COD payment record created.",
        entity_type="order",
        entity_id=order["id"],
        metadata={"payment_id": payment["id"], "gateway": "cod"},
    )

    return {
        "message": "COD payment created successfully",
        "payment": payment,
        "order": order,
        "duplicate_prevented": False,
    }


@router.patch("/{payment_id}/mark-paid")
def mark_payment_as_paid(
    payment_id: str,
    user=Depends(get_logged_in_user),
):
    user_id = user_id_from_user(user)
    payment = get_payment_for_user(payment_id, user_id)

    if payment.get("status") == "paid":
        invoice_result = safely_generate_invoice_after_payment(payment)

        return {
            "message": "Payment is already paid",
            "payment": payment,
            "invoice": invoice_result,
        }

    if payment.get("status") == "failed":
        raise HTTPException(
            status_code=400,
            detail="Failed payment cannot be marked paid. Create a new payment.",
        )

    already_paid_payment = get_paid_payment_for_order(
        order_id=payment["order_id"],
        user_id=user_id,
        exclude_payment_id=payment["id"],
    )

    if already_paid_payment:
        raise HTTPException(
            status_code=400,
            detail="This order already has a paid payment.",
        )

    updated_payment = update_payment_status(
        payment_id=payment["id"],
        status="paid",
        paid_at=now_iso(),
    )

    updated_order = confirm_order_after_payment(
        order_id=payment["order_id"],
        user_id=user_id,
    )

    refresh_customer_stats(updated_order.get("customer_id"), user_id)

    invoice_result = safely_generate_invoice_after_payment(updated_payment)

    create_payment_success_notification(updated_payment, updated_order)

    create_activity_log(
        user_id=user_id,
        action="payment_marked_paid",
        description=(
            f"Payment marked paid for order "
            f"{updated_order.get('order_number') or updated_order.get('id')}."
        ),
        entity_type="order",
        entity_id=updated_order["id"],
        metadata={
            "payment_id": updated_payment["id"],
            "amount": updated_payment.get("amount"),
            "gateway": updated_payment.get("gateway"),
        },
    )

    return {
        "message": "Payment marked as paid successfully",
        "payment": updated_payment,
        "order": updated_order,
        "invoice": invoice_result,
    }


@router.post("/razorpay/create-link")
def create_razorpay_payment_link(
    payload: RazorpayCreateLinkRequest,
    user=Depends(get_logged_in_user),
):
    user_id = user_id_from_user(user)
    order = get_order_for_user(payload.order_id, user_id)

    if order.get("status") == "cancelled":
        raise HTTPException(
            status_code=400,
            detail="Cannot create payment link for a cancelled order",
        )

    amount = to_float(order.get("total_amount"))

    if amount <= 0:
        raise HTTPException(status_code=400, detail="Order amount must be greater than 0")

    paid_payment = get_paid_payment_for_order(order["id"], user_id)

    if paid_payment:
        return {
            "message": "This order already has a paid payment.",
            "payment": paid_payment,
            "payment_url": paid_payment.get("payment_link_url"),
            "duplicate_prevented": True,
        }

    existing_razorpay_payment = get_existing_payment_for_order(
        order_id=order["id"],
        user_id=user_id,
        gateway="razorpay",
        statuses=["pending"],
    )

    if existing_razorpay_payment:
        return {
            "message": "Pending Razorpay link already exists.",
            "payment": existing_razorpay_payment,
            "payment_url": existing_razorpay_payment.get("payment_link_url"),
            "duplicate_prevented": True,
        }

    client = get_razorpay_client()

    try:
        payment_link = client.payment_link.create(
            {
                "amount": int(amount * 100),
                "currency": "INR",
                "accept_partial": False,
                "description": (
                    f"Payment for OrdiFy order "
                    f"{order.get('order_number') or order['id']}"
                ),
                "reference_id": order["id"],
                "callback_url": settings.RAZORPAY_CALLBACK_URL,
                "callback_method": "get",
                "notes": {
                    "order_id": order["id"],
                    "user_id": user_id,
                    "source": "ordify",
                },
            }
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Razorpay payment link creation failed: {str(error)}",
        )

    payment = create_payment_row(
        order_id=order["id"],
        user_id=user_id,
        gateway="razorpay",
        gateway_payment_id=payment_link.get("id"),
        amount=amount,
        currency="INR",
        status="pending",
        payment_link_url=payment_link.get("short_url"),
    )

    return {
        "message": "Razorpay payment link created successfully",
        "payment": payment,
        "payment_link": payment_link,
        "payment_url": payment_link.get("short_url"),
        "duplicate_prevented": False,
    }


@router.post("/razorpay/webhook")
async def razorpay_webhook(
    request: Request,
    x_razorpay_signature: str | None = Header(default=None),
):
    body = await request.body()

    verify_razorpay_webhook_signature(
        body=body,
        signature=x_razorpay_signature,
    )

    try:
        payload = json.loads(body.decode("utf-8"))
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid webhook JSON")

    event_name = payload.get("event")

    payment_link_entity = (
        payload.get("payload", {})
        .get("payment_link", {})
        .get("entity", {})
    )

    payment_entity = (
        payload.get("payload", {})
        .get("payment", {})
        .get("entity", {})
    )

    payment_link_id = payment_link_entity.get("id") if payment_link_entity else None
    order_id = payment_link_entity.get("reference_id") if payment_link_entity else None

    if not payment_link_id and payment_entity:
        notes = payment_entity.get("notes") or {}
        payment_link_id = payment_entity.get("payment_link_id")
        order_id = notes.get("order_id")

    payment = None
    invoice_result = None

    if payment_link_id:
        payment = find_payment_by_gateway_payment_id(payment_link_id)

    if payment and payment.get("status") != "paid":
        already_paid_payment = get_paid_payment_for_order(
            order_id=payment["order_id"],
            user_id=payment["user_id"],
            exclude_payment_id=payment["id"],
        )

        if already_paid_payment:
            return {
                "received": True,
                "event": event_name,
                "payment_updated": False,
                "message": "Order already has a paid payment.",
            }

        updated_payment = update_payment_status(
            payment_id=payment["id"],
            status="paid",
            paid_at=now_iso(),
        )

        updated_order = confirm_order_after_payment(
            order_id=payment["order_id"],
            user_id=payment["user_id"],
        )

        refresh_customer_stats(updated_order.get("customer_id"), payment["user_id"])

        invoice_result = safely_generate_invoice_after_payment(updated_payment)

        create_payment_success_notification(updated_payment, updated_order)

        create_activity_log(
            user_id=updated_payment["user_id"],
            action="razorpay_payment_received",
            description=(
                f"Razorpay payment received for order "
                f"{updated_order.get('order_number') or updated_order.get('id')}."
            ),
            entity_type="order",
            entity_id=updated_order["id"],
            metadata={
                "payment_id": updated_payment["id"],
                "payment_link_id": payment_link_id,
                "event": event_name,
            },
        )

    elif payment and payment.get("status") == "paid":
        invoice_result = safely_generate_invoice_after_payment(payment)

    return {
        "received": True,
        "event": event_name,
        "payment_updated": payment is not None,
        "order_id": order_id,
        "payment_link_id": payment_link_id,
        "invoice": invoice_result,
    }