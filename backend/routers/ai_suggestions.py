from fastapi import APIRouter, Depends

from core.auth import get_logged_in_user
from core.supabase import supabase

router = APIRouter(prefix="/ai", tags=["AI Suggestions"])


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


@router.get("/suggestions")
def get_ai_suggestions(user=Depends(get_logged_in_user)):
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

    user_order_ids = set(order.get("id") for order in orders)

    paid_payments = [
        payment for payment in payments if payment.get("status") == "paid"
    ]

    pending_payments = [
        payment for payment in payments if payment.get("status") == "pending"
    ]

    paid_order_ids = set(
        payment.get("order_id")
        for payment in paid_payments
        if payment.get("order_id")
    )

    total_revenue = sum(to_float(payment.get("amount")) for payment in paid_payments)
    total_orders = len(orders)
    paid_orders_count = len(paid_order_ids)

    suggestions = []
    priority_actions = []

    # 1. Low stock suggestions
    low_stock_products = []

    for product in products:
        stock = to_int(product.get("stock_count"))
        threshold = to_int(product.get("low_stock_threshold"))

        if threshold <= 0:
            threshold = 5

        if stock <= threshold:
            low_stock_products.append(product)

            suggestions.append(
                {
                    "type": "stock",
                    "priority": "high",
                    "title": f"Restock {product.get('name') or 'this product'}",
                    "message": f"Only {stock} item(s) left. Restock soon to avoid missing orders.",
                    "action": "Go to Stock page and update product quantity.",
                    "icon": "stock",
                }
            )

    if low_stock_products:
        priority_actions.append(
            f"Restock {len(low_stock_products)} low stock product(s)."
        )

    # 2. Pending payment suggestions
    if pending_payments:
        suggestions.append(
            {
                "type": "payment",
                "priority": "high",
                "title": "Follow up pending payments",
                "message": f"{len(pending_payments)} payment(s) are still pending.",
                "action": "Open Orders or Payments and follow up with customers.",
                "icon": "payment",
            }
        )

        priority_actions.append(
            f"Follow up {len(pending_payments)} pending payment(s)."
        )

    # 3. Product sales analysis
    product_sales = {}

    for item in order_items:
        order_id = item.get("order_id")

        if order_id not in user_order_ids:
            continue

        product_id = item.get("product_id")
        quantity = to_int(item.get("quantity"))
        unit_price = to_float(item.get("unit_price"))

        if not product_id:
            continue

        if product_id not in product_sales:
            product_sales[product_id] = {
                "quantity_sold": 0,
                "revenue": 0.0,
            }

        product_sales[product_id]["quantity_sold"] += quantity
        product_sales[product_id]["revenue"] += quantity * unit_price

    product_lookup = {
        product.get("id"): product
        for product in products
    }

    top_product = None

    if product_sales:
        top_product_id = max(
            product_sales,
            key=lambda product_id: product_sales[product_id]["quantity_sold"],
        )

        top_product_data = product_lookup.get(top_product_id)

        if top_product_data:
            top_product = {
                "name": top_product_data.get("name") or "Product",
                "quantity_sold": product_sales[top_product_id]["quantity_sold"],
                "revenue": round(product_sales[top_product_id]["revenue"], 2),
            }

            suggestions.append(
                {
                    "type": "growth",
                    "priority": "medium",
                    "title": f"{top_product['name']} is your best seller",
                    "message": f"It sold {top_product['quantity_sold']} unit(s). Keep this product visible and stocked.",
                    "action": "Promote this product more on Instagram.",
                    "icon": "growth",
                }
            )

    # 4. Slow moving product suggestions
    slow_moving_products = []

    for product in products:
        product_id = product.get("id")

        if product_id not in product_sales:
            slow_moving_products.append(product)

    if slow_moving_products:
        first_slow_product = slow_moving_products[0]

        suggestions.append(
            {
                "type": "sales",
                "priority": "medium",
                "title": "Some products are not selling yet",
                "message": f"{len(slow_moving_products)} product(s) have no sales recorded. Example: {first_slow_product.get('name') or 'Product'}.",
                "action": "Try discount, bundle offer, or Instagram story promotion.",
                "icon": "sales",
            }
        )

    # 5. Customer insights
    customer_spending = {}

    order_customer_lookup = {
        order.get("id"): order.get("customer_id")
        for order in orders
    }

    customer_lookup = {
        customer.get("id"): customer
        for customer in customers
    }

    for payment in paid_payments:
        order_id = payment.get("order_id")
        customer_id = order_customer_lookup.get(order_id)

        if not customer_id:
            continue

        if customer_id not in customer_spending:
            customer = customer_lookup.get(customer_id, {})

            customer_spending[customer_id] = {
                "name": customer.get("display_name")
                or customer.get("instagram_username")
                or "Customer",
                "total_spent": 0.0,
                "paid_orders": 0,
            }

        customer_spending[customer_id]["total_spent"] += to_float(payment.get("amount"))
        customer_spending[customer_id]["paid_orders"] += 1

    best_customer = None

    if customer_spending:
        best_customer_id = max(
            customer_spending,
            key=lambda customer_id: customer_spending[customer_id]["total_spent"],
        )

        best_customer = customer_spending[best_customer_id]

        suggestions.append(
            {
                "type": "customer",
                "priority": "medium",
                "title": f"{best_customer['name']} is your best customer",
                "message": f"They have spent ₹{round(best_customer['total_spent'], 2)} across {best_customer['paid_orders']} paid order(s).",
                "action": "Send a thank-you message or exclusive offer.",
                "icon": "customer",
            }
        )

    # 6. Business health suggestion
    if total_orders == 0:
        business_health_score = 0
    else:
        payment_health = round((paid_orders_count / total_orders) * 100)

        if products:
            stock_health = round(
                ((len(products) - len(low_stock_products)) / len(products)) * 100
            )
        else:
            stock_health = 0

        business_health_score = round((payment_health + stock_health) / 2)

    if business_health_score >= 80:
        suggestions.append(
            {
                "type": "health",
                "priority": "low",
                "title": "Business health looks strong",
                "message": f"Your current business health score is {business_health_score}%.",
                "action": "Keep maintaining stock and payment follow-ups.",
                "icon": "health",
            }
        )
    elif business_health_score >= 50:
        suggestions.append(
            {
                "type": "health",
                "priority": "medium",
                "title": "Business health is moderate",
                "message": f"Your current business health score is {business_health_score}%.",
                "action": "Improve pending payments and low stock items.",
                "icon": "health",
            }
        )
    else:
        suggestions.append(
            {
                "type": "health",
                "priority": "high",
                "title": "Business health needs attention",
                "message": f"Your current business health score is {business_health_score}%.",
                "action": "Focus on getting paid orders and keeping products in stock.",
                "icon": "health",
            }
        )

    # 7. Beginner business summary
    if total_revenue > 0:
        summary = (
            f"Your business has earned ₹{round(total_revenue, 2)} "
            f"from {paid_orders_count} paid order(s). "
            f"You have {len(products)} product(s), {len(customers)} customer(s), "
            f"and {len(low_stock_products)} low stock product(s)."
        )
    else:
        summary = (
            "Your store is ready, but no paid revenue is recorded yet. "
            "Create orders, mark payments as paid, and OrdiFy will start giving stronger insights."
        )

    if not priority_actions:
        priority_actions.append("Keep adding orders and payments to improve insights.")

    return {
        "summary": summary,
        "business_health_score": business_health_score,
        "total_revenue": round(total_revenue, 2),
        "total_orders": total_orders,
        "paid_orders": paid_orders_count,
        "pending_payments": len(pending_payments),
        "low_stock_products": len(low_stock_products),
        "top_product": top_product,
        "best_customer": best_customer,
        "priority_actions": priority_actions,
        "suggestions": suggestions,
    }