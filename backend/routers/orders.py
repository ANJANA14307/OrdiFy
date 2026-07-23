from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from core.auth import get_logged_in_user
from core.supabase import supabase
from schemas.order import OrderCreate, OrderStatusUpdate
from services.activity_service import create_activity_log
from services.notification_service import create_notification


router = APIRouter(
    prefix="/orders",
    tags=["Orders"],
)

ORDER_FLOW = ["new", "confirmed", "packed", "shipped", "delivered"]
ALL_STATUSES = ["new", "confirmed", "packed", "shipped", "delivered", "cancelled"]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def get_user_id(user) -> str:
    if hasattr(user, "id"):
        return str(user.id)

    if isinstance(user, dict) and user.get("id"):
        return str(user["id"])

    raise HTTPException(status_code=401, detail="Invalid user")


def clean_optional(value: str | None) -> str | None:
    if value is None:
        return None

    cleaned = value.strip()

    return cleaned or None


def fetch_customer(customer_id: str, user_id: str) -> dict:
    response = (
        supabase.table("customers")
        .select("*")
        .eq("id", customer_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )

    if not response.data:
        raise HTTPException(status_code=404, detail="Customer not found")

    return response.data[0]


def fetch_product(product_id: str, user_id: str) -> dict:
    response = (
        supabase.table("products")
        .select("*")
        .eq("id", product_id)
        .eq("user_id", user_id)
        .eq("is_active", True)
        .limit(1)
        .execute()
    )

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail=f"Product not found: {product_id}",
        )

    return response.data[0]


def fetch_order(order_id: str, user_id: str) -> dict:
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


def fetch_order_items(order_id: str) -> list[dict]:
    response = (
        supabase.table("order_items")
        .select("*")
        .eq("order_id", order_id)
        .execute()
    )

    return response.data or []


def fetch_payments(order_id: str, user_id: str) -> list[dict]:
    try:
        response = (
            supabase.table("payments")
            .select("*")
            .eq("order_id", order_id)
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )

        return response.data or []
    except Exception:
        return []


def fetch_invoices(order_id: str) -> list[dict]:
    try:
        response = (
            supabase.table("invoices")
            .select("*")
            .eq("order_id", order_id)
            .order("created_at", desc=True)
            .execute()
        )

        return response.data or []
    except Exception:
        return []


def payment_status_from_payments(payments: list[dict]) -> str:
    if not payments:
        return "unpaid"

    for payment in payments:
        if payment.get("status") == "paid":
            return "paid"

    return "pending"


def attach_order_detail(order: dict, user_id: str) -> dict:
    customer = None

    if order.get("customer_id"):
        try:
            customer = fetch_customer(str(order["customer_id"]), user_id)
        except HTTPException:
            customer = None

    raw_items = fetch_order_items(str(order["id"]))

    detailed_items = []

    for item in raw_items:
        product = None

        product_id = item.get("product_id")

        if product_id:
            product_response = (
                supabase.table("products")
                .select("id,name,price,image_url,stock_count")
                .eq("id", product_id)
                .eq("user_id", user_id)
                .limit(1)
                .execute()
            )

            if product_response.data:
                product = product_response.data[0]

        detailed_items.append(
            {
                **item,
                "product": product,
            }
        )

    payments = fetch_payments(str(order["id"]), user_id)
    invoices = fetch_invoices(str(order["id"]))

    return {
        **order,
        "customer": customer,
        "items": detailed_items,
        "payments": payments,
        "invoices": invoices,
        "item_count": len(detailed_items),
        "total_quantity": sum(
            int(item.get("quantity") or 0) for item in detailed_items
        ),
        "payment_status": payment_status_from_payments(payments),
    }


def assert_valid_status_change(current_status: str, new_status: str) -> None:
    if new_status not in ALL_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid order status")

    if current_status == new_status:
        return

    if current_status == "cancelled":
        raise HTTPException(
            status_code=400,
            detail="Cancelled orders cannot be updated",
        )

    if current_status == "delivered" and new_status == "cancelled":
        raise HTTPException(
            status_code=400,
            detail="Delivered orders cannot be cancelled",
        )

    if new_status == "cancelled":
        return

    if current_status not in ORDER_FLOW or new_status not in ORDER_FLOW:
        raise HTTPException(status_code=400, detail="Invalid order status")

    if ORDER_FLOW.index(new_status) < ORDER_FLOW.index(current_status):
        raise HTTPException(
            status_code=400,
            detail="Order status cannot move backwards",
        )


def should_decrement_stock(current_status: str, new_status: str) -> bool:
    return current_status == "new" and new_status == "confirmed"


def should_restore_stock(current_status: str, new_status: str) -> bool:
    return (
        new_status == "cancelled"
        and current_status in ["confirmed", "packed", "shipped"]
    )


def assert_stock_available_for_items(items: list[dict], user_id: str) -> None:
    for item in items:
        product_id = str(item.get("product_id"))
        quantity = int(item.get("quantity") or 0)

        if quantity <= 0:
            raise HTTPException(status_code=400, detail="Invalid item quantity")

        product = fetch_product(product_id, user_id)
        current_stock = int(product.get("stock_count") or 0)

        if current_stock < quantity:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Not enough stock for {product.get('name')}. "
                    f"Available: {current_stock}, required: {quantity}"
                ),
            )


def decrement_stock_for_order(order_id: str, user_id: str) -> None:
    items = fetch_order_items(order_id)

    if not items:
        raise HTTPException(status_code=400, detail="Order has no items")

    assert_stock_available_for_items(items, user_id)

    for item in items:
        product_id = str(item.get("product_id"))
        quantity = int(item.get("quantity") or 0)

        product = fetch_product(product_id, user_id)
        current_stock = int(product.get("stock_count") or 0)

        (
            supabase.table("products")
            .update({"stock_count": current_stock - quantity})
            .eq("id", product_id)
            .eq("user_id", user_id)
            .execute()
        )


def restore_stock_for_order(order_id: str, user_id: str) -> None:
    items = fetch_order_items(order_id)

    for item in items:
        product_id = str(item.get("product_id"))
        quantity = int(item.get("quantity") or 0)

        if quantity <= 0:
            continue

        product_response = (
            supabase.table("products")
            .select("*")
            .eq("id", product_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )

        if not product_response.data:
            continue

        product = product_response.data[0]
        current_stock = int(product.get("stock_count") or 0)

        (
            supabase.table("products")
            .update({"stock_count": current_stock + quantity})
            .eq("id", product_id)
            .eq("user_id", user_id)
            .execute()
        )


def refresh_customer_stats(customer_id: str, user_id: str) -> None:
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
        total_spent = sum(float(order.get("total_amount") or 0) for order in orders)

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


def create_order_number(order_id: str) -> str:
    return f"ORD-{order_id[:8].upper()}"


@router.post("")
def create_order(payload: OrderCreate, user=Depends(get_logged_in_user)):
    user_id = get_user_id(user)

    if not payload.items:
        raise HTTPException(status_code=400, detail="Order must have at least one item")

    fetch_customer(payload.customer_id, user_id)

    prepared_items = []
    total_amount = 0.0

    for item in payload.items:
        product = fetch_product(item.product_id, user_id)

        quantity = int(item.quantity)
        current_stock = int(product.get("stock_count") or 0)

        if current_stock < quantity:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Not enough stock for {product.get('name')}. "
                    f"Available: {current_stock}, required: {quantity}"
                ),
            )

        unit_price = item.unit_price

        if unit_price is None:
            unit_price = float(product.get("price") or 0)

        if unit_price <= 0:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid price for product {product.get('name')}",
            )

        total_amount += unit_price * quantity

        prepared_items.append(
            {
                "product_id": item.product_id,
                "quantity": quantity,
                "unit_price": unit_price,
                "variant_notes": clean_optional(item.variant_notes),
            }
        )

    order_data = {
        "user_id": user_id,
        "customer_id": payload.customer_id,
        "status": "new",
        "source": payload.source,
        "notes": clean_optional(payload.notes),
        "custom_variant": clean_optional(payload.custom_variant),
        "total_amount": total_amount,
    }

    order_response = supabase.table("orders").insert(order_data).select().execute()

    if not order_response.data:
        raise HTTPException(status_code=500, detail="Failed to create order")

    order = order_response.data[0]
    order_id = str(order["id"])

    try:
        (
            supabase.table("orders")
            .update({"order_number": create_order_number(order_id)})
            .eq("id", order_id)
            .eq("user_id", user_id)
            .execute()
        )
    except Exception:
        pass

    order_items_data = [
        {
            "order_id": order_id,
            **item,
        }
        for item in prepared_items
    ]

    items_response = supabase.table("order_items").insert(order_items_data).select().execute()

    if not items_response.data:
        try:
            supabase.table("orders").delete().eq("id", order_id).eq(
                "user_id", user_id
            ).execute()
        except Exception:
            pass

        raise HTTPException(status_code=500, detail="Failed to create order items")

    refresh_customer_stats(payload.customer_id, user_id)

    create_activity_log(
        user_id=user_id,
        action="order_created",
        description=f"Created order worth ₹{total_amount:.2f}",
        entity_type="order",
        entity_id=order_id,
        metadata={"total_amount": total_amount, "source": payload.source},
    )

    create_notification(
        user_id=user_id,
        title="New order created",
        message=f"Order created successfully for ₹{total_amount:.2f}",
        notification_type="success",
        entity_type="order",
        entity_id=order_id,
    )

    fresh_order = fetch_order(order_id, user_id)
    detailed_order = attach_order_detail(fresh_order, user_id)

    return {
        "message": "Order created successfully",
        "order": detailed_order,
        "customer": detailed_order.get("customer"),
        "items": detailed_order.get("items", []),
        "payments": detailed_order.get("payments", []),
        "invoices": detailed_order.get("invoices", []),
    }


@router.get("")
def list_orders(
    status: Optional[str] = Query(default=None),
    customer_id: Optional[str] = Query(default=None),
    date_from: Optional[str] = Query(default=None),
    date_to: Optional[str] = Query(default=None),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, ge=1, le=100),
    user=Depends(get_logged_in_user),
):
    user_id = get_user_id(user)

    query = (
        supabase.table("orders")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
    )

    if status:
        if status not in ALL_STATUSES:
            raise HTTPException(status_code=400, detail="Invalid order status")

        query = query.eq("status", status)

    if customer_id:
        query = query.eq("customer_id", customer_id)

    if date_from:
        query = query.gte("created_at", date_from)

    if date_to:
        query = query.lte("created_at", date_to)

    start = (page - 1) * limit
    end = start + limit - 1

    response = query.range(start, end).execute()

    orders = response.data or []
    detailed_orders = [attach_order_detail(order, user_id) for order in orders]

    counts = {status_name: 0 for status_name in ALL_STATUSES}

    for order in detailed_orders:
        order_status = order.get("status") or "new"

        if order_status in counts:
            counts[order_status] += 1

    return {
        "orders": detailed_orders,
        "page": page,
        "limit": limit,
        "count": len(detailed_orders),
        "status_counts": counts,
    }


@router.get("/{order_id}")
def get_order(order_id: str, user=Depends(get_logged_in_user)):
    user_id = get_user_id(user)

    order = fetch_order(order_id, user_id)
    detailed_order = attach_order_detail(order, user_id)

    return {
        "order": detailed_order,
        "customer": detailed_order.get("customer"),
        "items": detailed_order.get("items", []),
        "payments": detailed_order.get("payments", []),
        "invoices": detailed_order.get("invoices", []),
    }


@router.patch("/{order_id}/status")
def update_order_status(
    order_id: str,
    payload: OrderStatusUpdate,
    user=Depends(get_logged_in_user),
):
    user_id = get_user_id(user)

    order = fetch_order(order_id, user_id)

    current_status = order.get("status") or "new"
    new_status = payload.status

    assert_valid_status_change(current_status, new_status)

    if should_decrement_stock(current_status, new_status):
        decrement_stock_for_order(order_id, user_id)

    if should_restore_stock(current_status, new_status):
        restore_stock_for_order(order_id, user_id)

    update_data = {
        "status": new_status,
        "updated_at": now_iso(),
    }

    update_response = (
        supabase.table("orders")
        .update(update_data)
        .eq("id", order_id)
        .eq("user_id", user_id)
        .select()
        .execute()
    )

    if not update_response.data:
        raise HTTPException(status_code=500, detail="Failed to update order")

    fresh_order = fetch_order(order_id, user_id)
    detailed_order = attach_order_detail(fresh_order, user_id)

    customer_id = str(fresh_order.get("customer_id") or "")
    if customer_id:
        refresh_customer_stats(customer_id, user_id)

    create_activity_log(
        user_id=user_id,
        action="order_status_updated",
        description=f"Order moved from {current_status} to {new_status}",
        entity_type="order",
        entity_id=order_id,
        metadata={
            "from_status": current_status,
            "to_status": new_status,
        },
    )

    notification_type = "success"
    if new_status == "cancelled":
        notification_type = "warning"
    elif new_status in ["confirmed", "packed", "shipped"]:
        notification_type = "info"

    create_notification(
        user_id=user_id,
        title="Order status updated",
        message=f"Order moved to {new_status}",
        notification_type=notification_type,
        entity_type="order",
        entity_id=order_id,
    )

    return {
        "message": "Order status updated successfully",
        "order": detailed_order,
        "customer": detailed_order.get("customer"),
        "items": detailed_order.get("items", []),
        "payments": detailed_order.get("payments", []),
        "invoices": detailed_order.get("invoices", []),
    }


@router.delete("/{order_id}")
def cancel_order(order_id: str, user=Depends(get_logged_in_user)):
    user_id = get_user_id(user)

    order = fetch_order(order_id, user_id)

    current_status = order.get("status") or "new"

    if current_status == "cancelled":
        detailed_order = attach_order_detail(order, user_id)

        return {
            "message": "Order already cancelled",
            "order": detailed_order,
            "customer": detailed_order.get("customer"),
            "items": detailed_order.get("items", []),
            "payments": detailed_order.get("payments", []),
            "invoices": detailed_order.get("invoices", []),
        }

    if current_status == "delivered":
        raise HTTPException(
            status_code=400,
            detail="Delivered orders cannot be cancelled",
        )

    if current_status in ["confirmed", "packed", "shipped"]:
        restore_stock_for_order(order_id, user_id)

    update_data = {
        "status": "cancelled",
        "updated_at": now_iso(),
    }

    update_response = (
        supabase.table("orders")
        .update(update_data)
        .eq("id", order_id)
        .eq("user_id", user_id)
        .select()
        .execute()
    )

    if not update_response.data:
        raise HTTPException(status_code=500, detail="Failed to cancel order")

    fresh_order = fetch_order(order_id, user_id)
    detailed_order = attach_order_detail(fresh_order, user_id)

    customer_id = str(fresh_order.get("customer_id") or "")
    if customer_id:
        refresh_customer_stats(customer_id, user_id)

    create_activity_log(
        user_id=user_id,
        action="order_cancelled",
        description="Order cancelled",
        entity_type="order",
        entity_id=order_id,
        metadata={"previous_status": current_status},
    )

    create_notification(
        user_id=user_id,
        title="Order cancelled",
        message="Order was cancelled successfully",
        notification_type="warning",
        entity_type="order",
        entity_id=order_id,
    )

    return {
        "message": "Order cancelled successfully",
        "order": detailed_order,
        "customer": detailed_order.get("customer"),
        "items": detailed_order.get("items", []),
        "payments": detailed_order.get("payments", []),
        "invoices": detailed_order.get("invoices", []),
    }