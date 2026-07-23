from fastapi import APIRouter, Depends
from core.auth import get_logged_in_user
from core.supabase import supabase

router = APIRouter(prefix="/analytics", tags=["Analytics"])


def to_float(value):
    try:
        return float(value)
    except Exception:
        return 0.0


def to_int(value):
    try:
        return int(value)
    except Exception:
        return 0


@router.get("/dashboard")
def get_analytics_dashboard(user=Depends(get_logged_in_user)):
    user_id = user.id

    orders_response = (
        supabase.table("orders")
        .select("*")
        .eq("user_id", user_id)
        .execute()
    )

    payments_response = (
        supabase.table("payments")
        .select("*")
        .eq("user_id", user_id)
        .execute()
    )

    products_response = (
        supabase.table("products")
        .select("*")
        .eq("user_id", user_id)
        .execute()
    )

    customers_response = (
        supabase.table("customers")
        .select("*")
        .eq("user_id", user_id)
        .execute()
    )

    order_items_response = (
        supabase.table("order_items")
        .select("*")
        .execute()
    )

    orders = orders_response.data or []
    payments = payments_response.data or []
    products = products_response.data or []
    customers = customers_response.data or []
    order_items = order_items_response.data or []

    total_orders = len(orders)
    total_products = len(products)
    total_customers = len(customers)

    paid_payments = [
        payment for payment in payments if payment.get("status") == "paid"
    ]

    pending_payments = [
        payment for payment in payments if payment.get("status") == "pending"
    ]

    total_revenue = sum(to_float(payment.get("amount")) for payment in paid_payments)

    paid_orders_count = len(
        set(payment.get("order_id") for payment in paid_payments if payment.get("order_id"))
    )

    low_stock_products = []

    for product in products:
        stock = to_int(product.get("stock_count"))
        threshold = to_int(product.get("low_stock_threshold"))

        if threshold <= 0:
            threshold = 5

        if stock <= threshold:
            low_stock_products.append(product)

    confirmed_orders = [
        order for order in orders if order.get("status") == "confirmed"
    ]

    delivered_orders = [
        order for order in orders if order.get("status") == "delivered"
    ]

    cancelled_orders = [
        order for order in orders if order.get("status") == "cancelled"
    ]

    product_sales = {}

    user_order_ids = set(order.get("id") for order in orders)

    for item in order_items:
        order_id = item.get("order_id")

        if order_id not in user_order_ids:
            continue

        product_id = item.get("product_id")
        quantity = to_int(item.get("quantity"))

        if not product_id:
            continue

        if product_id not in product_sales:
            product_sales[product_id] = {
                "product_id": product_id,
                "quantity_sold": 0,
                "revenue": 0.0,
            }

        product_sales[product_id]["quantity_sold"] += quantity
        product_sales[product_id]["revenue"] += quantity * to_float(
            item.get("unit_price")
        )

    product_name_lookup = {
        product.get("id"): product.get("name") or "Product"
        for product in products
    }

    top_products = []

    for product_id, data in product_sales.items():
        top_products.append(
            {
                "product_id": product_id,
                "name": product_name_lookup.get(product_id, "Product"),
                "quantity_sold": data["quantity_sold"],
                "revenue": round(data["revenue"], 2),
            }
        )

    top_products.sort(
        key=lambda product: product["quantity_sold"],
        reverse=True,
    )

    recent_paid_orders = []

    for payment in paid_payments:
        order_id = payment.get("order_id")

        matching_order = next(
            (order for order in orders if order.get("id") == order_id),
            None,
        )

        if matching_order:
            recent_paid_orders.append(
                {
                    "order_id": order_id,
                    "order_number": matching_order.get("order_number") or order_id,
                    "amount": payment.get("amount"),
                    "gateway": payment.get("gateway"),
                    "paid_at": payment.get("paid_at"),
                }
            )

    recent_paid_orders.sort(
        key=lambda order: order.get("paid_at") or "",
        reverse=True,
    )

    if total_products == 0:
        stock_health = 0
    else:
        stock_health = round(
            ((total_products - len(low_stock_products)) / total_products) * 100
        )

    if total_orders == 0:
        payment_health = 0
    else:
        payment_health = round((paid_orders_count / total_orders) * 100)

    business_health_score = round((stock_health + payment_health) / 2)

    return {
        "summary": {
            "total_revenue": round(total_revenue, 2),
            "total_orders": total_orders,
            "paid_orders": paid_orders_count,
            "pending_payments": len(pending_payments),
            "total_customers": total_customers,
            "total_products": total_products,
            "low_stock_products": len(low_stock_products),
            "confirmed_orders": len(confirmed_orders),
            "delivered_orders": len(delivered_orders),
            "cancelled_orders": len(cancelled_orders),
            "business_health_score": business_health_score,
            "stock_health": stock_health,
            "payment_health": payment_health,
        },
        "top_products": top_products[:5],
        "recent_paid_orders": recent_paid_orders[:5],
        "low_stock_items": low_stock_products[:5],
    }