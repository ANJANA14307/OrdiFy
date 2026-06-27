from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from core.auth import get_logged_in_user
from core.supabase import supabase
from schemas.order import OrderCreate, OrderStatusUpdate

router = APIRouter(
    prefix="/orders",
    tags=["Orders"],
)

ORDER_FLOW = ["new", "confirmed", "packed", "shipped", "delivered"]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def get_user_id(user) -> str:
    if hasattr(user, "id"):
        return user.id
    if isinstance(user, dict):
        return user.get("id")
    raise HTTPException(status_code=401, detail="Invalid user")


def fetch_customer(customer_id: str, user_id: str):
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


def fetch_product(product_id: str, user_id: str):
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
        raise HTTPException(status_code=404, detail=f"Product not found: {product_id}")

    return response.data[0]


def fetch_order(order_id: str, user_id: str):
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


def fetch_order_items(order_id: str):
    response = (
        supabase.table("order_items")
        .select("*")
        .eq("order_id", order_id)
        .execute()
    )

    return response.data or []


def fetch_payment_status(order_id: str, user_id: str):
    response = (
        supabase.table("payments")
        .select("*")
        .eq("order_id", order_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )

    if not response.data:
        return "pending"

    return response.data[0].get("status", "pending")


def attach_order_detail(order: dict, user_id: str):
    customer = None
    if order.get("customer_id"):
        customer_response = (
            supabase.table("customers")
            .select("*")
            .eq("id", order["customer_id"])
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if customer_response.data:
            customer = customer_response.data[0]

    items = fetch_order_items(order["id"])

    detailed_items = []
    for item in items:
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

    return {
        **order,
        "customer": customer,
        "items": detailed_items,
        "item_count": len(items),
        "total_quantity": sum(int(item.get("quantity") or 0) for item in items),
        "payment_status": fetch_payment_status(order["id"], user_id),
    }


def assert_valid_status_change(current_status: str, new_status: str):
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


def decrement_stock_for_order(order_id: str, user_id: str):
    items = fetch_order_items(order_id)

    if not items:
        raise HTTPException(status_code=400, detail="Order has no items")

    products_to_update = []

    for item in items:
        product_id = item.get("product_id")
        quantity = int(item.get("quantity") or 0)

        if quantity <= 0:
            raise HTTPException(status_code=400, detail="Invalid order item quantity")

        product = fetch_product(product_id, user_id)
        current_stock = int(product.get("stock_count") or 0)

        if current_stock < quantity:
            raise HTTPException(
                status_code=400,
                detail=f"Not enough stock for {product.get('name')}. Available: {current_stock}, required: {quantity}",
            )

        products_to_update.append(
            {
                "product_id": product_id,
                "new_stock": current_stock - quantity,
            }
        )

    for item in products_to_update:
        (
            supabase.table("products")
            .update({"stock_count": item["new_stock"]})
            .eq("id", item["product_id"])
            .eq("user_id", user_id)
            .execute()
        )


def restore_stock_for_order(order_id: str, user_id: str):
    items = fetch_order_items(order_id)

    for item in items:
        product_id = item.get("product_id")
        quantity = int(item.get("quantity") or 0)

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


@router.post("")
def create_order(payload: OrderCreate, user=Depends(get_logged_in_user)):
    user_id = get_user_id(user)

    if not payload.items:
        raise HTTPException(status_code=400, detail="Order must have at least one item")

    fetch_customer(payload.customer_id, user_id)

    prepared_items = []
    total_amount = 0

    for item in payload.items:
        product = fetch_product(item.product_id, user_id)

        quantity = item.quantity
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
                "variant_notes": item.variant_notes,
            }
        )

    order_data = {
        "user_id": user_id,
        "customer_id": payload.customer_id,
        "status": "new",
        "source": payload.source,
        "notes": payload.notes,
        "custom_variant": payload.custom_variant,
        "total_amount": total_amount,
    }

    order_response = supabase.table("orders").insert(order_data).execute()

    if not order_response.data:
        raise HTTPException(status_code=500, detail="Failed to create order")

    order = order_response.data[0]
    order_id = order["id"]

    order_items_data = [
        {
            "order_id": order_id,
            **item,
        }
        for item in prepared_items
    ]

    items_response = supabase.table("order_items").insert(order_items_data).execute()

    if not items_response.data:
        raise HTTPException(status_code=500, detail="Failed to create order items")

    fresh_order = fetch_order(order_id, user_id)

    return {
        "message": "Order created successfully",
        "order": attach_order_detail(fresh_order, user_id),
    }


@router.get("")
def list_orders(
    status: Optional[str] = Query(default=None),
    customer_id: Optional[str] = Query(default=None),
    date_from: Optional[str] = Query(default=None),
    date_to: Optional[str] = Query(default=None),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
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

    return {
        "orders": [attach_order_detail(order, user_id) for order in orders],
        "page": page,
        "limit": limit,
        "count": len(orders),
    }


@router.get("/{order_id}")
def get_order(order_id: str, user=Depends(get_logged_in_user)):
    user_id = get_user_id(user)

    order = fetch_order(order_id, user_id)

    return {
        "order": attach_order_detail(order, user_id),
    }


@router.patch("/{order_id}/status")
def update_order_status(
    order_id: str,
    payload: OrderStatusUpdate,
    user=Depends(get_logged_in_user),
):
    user_id = get_user_id(user)

    order = fetch_order(order_id, user_id)

    current_status = order.get("status")
    new_status = payload.status
    stock_processed = bool(order.get("stock_processed"))

    assert_valid_status_change(current_status, new_status)

    update_data = {
        "status": new_status,
        "updated_at": now_iso(),
    }

    timestamp_columns = {
        "confirmed": "confirmed_at",
        "packed": "packed_at",
        "shipped": "shipped_at",
        "delivered": "delivered_at",
        "cancelled": "cancelled_at",
    }

    if new_status in timestamp_columns:
        update_data[timestamp_columns[new_status]] = now_iso()

    if new_status == "confirmed" and not stock_processed:
        decrement_stock_for_order(order_id, user_id)
        update_data["stock_processed"] = True

    if new_status == "cancelled" and stock_processed:
        restore_stock_for_order(order_id, user_id)
        update_data["stock_processed"] = False

    update_response = (
        supabase.table("orders")
        .update(update_data)
        .eq("id", order_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not update_response.data:
        raise HTTPException(status_code=500, detail="Failed to update order")

    fresh_order = fetch_order(order_id, user_id)

    return {
        "message": "Order status updated successfully",
        "order": attach_order_detail(fresh_order, user_id),
    }


@router.delete("/{order_id}")
def cancel_order(order_id: str, user=Depends(get_logged_in_user)):
    user_id = get_user_id(user)

    order = fetch_order(order_id, user_id)

    if order.get("status") == "cancelled":
        return {
            "message": "Order already cancelled",
            "order": attach_order_detail(order, user_id),
        }

    if order.get("status") == "delivered":
        raise HTTPException(
            status_code=400,
            detail="Delivered orders cannot be cancelled",
        )

    stock_processed = bool(order.get("stock_processed"))

    if stock_processed:
        restore_stock_for_order(order_id, user_id)

    update_data = {
        "status": "cancelled",
        "cancelled_at": now_iso(),
        "updated_at": now_iso(),
        "stock_processed": False,
    }

    update_response = (
        supabase.table("orders")
        .update(update_data)
        .eq("id", order_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not update_response.data:
        raise HTTPException(status_code=500, detail="Failed to cancel order")

    fresh_order = fetch_order(order_id, user_id)

    return {
        "message": "Order cancelled successfully",
        "order": attach_order_detail(fresh_order, user_id),
    }