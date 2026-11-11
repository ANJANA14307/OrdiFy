import hashlib
import hmac
import re
import secrets
from datetime import datetime, timezone
from typing import Any
from urllib.parse import quote

import httpx
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from fastapi.responses import PlainTextResponse

from core.auth import get_logged_in_user
from core.config import settings
from core.supabase import supabase
from routers.delivery_fees import calculate_delivery_quote
from schemas.whatsapp_order import (
    MessageTemplatesUpdate,
    SocialOrderAction,
    WhatsAppConfigUpdate,
)
from services.activity_service import create_activity_log
from services.notification_service import create_notification


router = APIRouter(prefix="/whatsapp-orders", tags=["WhatsApp Ordering"])
webhook_router = APIRouter(prefix="/webhooks/whatsapp", tags=["WhatsApp Webhook"])
GRAPH_API_BASE = "https://graph.facebook.com/v22.0"
ORDER_MESSAGE_TEMPLATE = (
    "ORDER <PRODUCT-CODE> / QTY 1 / NAME Your Name / PHONE +91XXXXXXXXXX / "
    "PIN 123456 / ADDRESS Full delivery address / PAYMENT COD"
)
DEFAULT_TEMPLATES = {
    "confirmation": (
        "Hi {name}, we received your order {order_id}. "
        "Total: ₹{total}. Reply CONFIRM {order_id} to place it."
    ),
    "shipped": "Hi {name}, order {order_id} has shipped. Total: ₹{total}.",
    "delivered": "Hi {name}, order {order_id} has been delivered. Total: ₹{total}.",
}


def _business_id(user: Any) -> str:
    user_id = getattr(user, "id", None)
    if user_id:
        return str(user_id)
    if isinstance(user, dict) and user.get("id"):
        return str(user["id"])
    raise HTTPException(status_code=401, detail="Invalid user")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _digits(value: str | None) -> str:
    return re.sub(r"\D", "", value or "")


def _get_config(business_id: str) -> dict | None:
    response = (
        supabase.table("whatsapp_order_settings")
        .select("*")
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None


def _format_template(template: str, values: dict[str, str]) -> str:
    return re.sub(
        r"\{(name|order_id|total)\}",
        lambda match: values[match.group(1)],
        template,
    )


def notify_social_order_status(
    business_id: str,
    order_id: str,
    status: str,
    order_number: str,
    total_amount: float,
) -> str | None:
    template_name = {"shipped": "shipped", "delivered": "delivered"}.get(status)
    if not template_name:
        return None
    response = (
        supabase.table("whatsapp_social_orders")
        .select("*")
        .eq("business_id", business_id)
        .eq("order_id", order_id)
        .limit(1)
        .execute()
    )
    if not response.data:
        return None
    social_order = response.data[0]
    config = _get_config(business_id) or {}
    if not config.get("is_enabled"):
        return None
    templates = config.get("templates") or DEFAULT_TEMPLATES
    message = _format_template(
        templates.get(template_name, DEFAULT_TEMPLATES[template_name]),
        {
            "name": social_order.get("customer_name") or "there",
            "order_id": order_number,
            "total": f"{total_amount:.2f}",
        },
    )
    try:
        _send_message(
            str(config.get("phone_number_id") or ""),
            str(social_order["customer_phone"]),
            message,
        )
    except HTTPException as error:
        validation = dict(social_order.get("validation_result") or {})
        validation["message_error"] = str(error.detail)
        messages = list(social_order.get("messages") or [])
        messages.append(
            _message_event(
                "system",
                f"Order moved to {status}, but WhatsApp message failed: {error.detail}",
            )
        )
        (
            supabase.table("whatsapp_social_orders")
            .update(
                {
                    "messages": messages,
                    "validation_result": validation,
                    "updated_at": _now(),
                }
            )
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .execute()
        )
        return str(error.detail)

    messages = list(social_order.get("messages") or [])
    messages.append(_message_event("outbound", message))
    (
        supabase.table("whatsapp_social_orders")
        .update({"messages": messages, "updated_at": _now()})
        .eq("id", social_order["id"])
        .eq("business_id", business_id)
        .execute()
    )
    return None


def _wa_link(phone_number: str, message: str = ORDER_MESSAGE_TEMPLATE) -> str:
    return f"https://wa.me/{_digits(phone_number)}?text={quote(message)}"


def _config_response(config: dict | None, business_id: str) -> dict:
    config = config or {}
    phone_number = str(config.get("phone_number") or "")
    phone_number_id = str(config.get("phone_number_id") or "")
    enabled = bool(config.get("is_enabled"))
    has_token = bool(settings.WHATSAPP_ACCESS_TOKEN)
    has_webhook_secrets = bool(
        settings.META_APP_SECRET
        and (settings.WHATSAPP_VERIFY_TOKEN or settings.VERIFY_TOKEN)
    )
    if (
        enabled
        and phone_number
        and phone_number_id
        and has_token
        and has_webhook_secrets
    ):
        status = "connected"
        error = None
    elif enabled and (not has_token or not has_webhook_secrets):
        status = "error"
        missing = []
        if not has_token:
            missing.append("WHATSAPP_ACCESS_TOKEN")
        if not settings.META_APP_SECRET:
            missing.append("META_APP_SECRET")
        if not (settings.WHATSAPP_VERIFY_TOKEN or settings.VERIFY_TOKEN):
            missing.append("WHATSAPP_VERIFY_TOKEN")
        error = (
            "Configure these backend environment variables: "
            + ", ".join(missing)
        )
    else:
        status = "pending"
        error = None

    return {
        "config": {
            "business_id": business_id,
            "phone_number": phone_number,
            "phone_number_id": phone_number_id,
            "is_enabled": enabled,
            "status": status,
            "error": error,
            "order_message_template": ORDER_MESSAGE_TEMPLATE,
            "order_link": _wa_link(phone_number) if phone_number else None,
            "templates": config.get("templates") or DEFAULT_TEMPLATES,
        }
    }


def _send_message(phone_number_id: str, recipient: str, message: str) -> None:
    access_token = settings.WHATSAPP_ACCESS_TOKEN
    if not access_token:
        raise HTTPException(
            status_code=503,
            detail="WhatsApp Cloud API access token is not configured",
        )

    try:
        response = httpx.post(
            f"{GRAPH_API_BASE}/{phone_number_id}/messages",
            headers={"Authorization": f"Bearer {access_token}"},
            json={
                "messaging_product": "whatsapp",
                "recipient_type": "individual",
                "to": _digits(recipient),
                "type": "text",
                "text": {"preview_url": False, "body": message},
            },
            timeout=20,
        )
    except httpx.RequestError as error:
        raise HTTPException(
            status_code=502,
            detail=f"WhatsApp could not be reached: {error}",
        ) from error
    if response.is_error:
        raise HTTPException(
            status_code=502,
            detail=f"WhatsApp could not send the message: {response.text}",
        )


def _parse_order_message(text: str) -> dict[str, str]:
    parts = [part.strip() for part in text.split("/") if part.strip()]
    if not parts or not re.match(r"^ORDER\s+", parts[0], re.IGNORECASE):
        raise ValueError("Start the message with ORDER followed by a product code")
    result = {"code": parts[0][len("ORDER"):].strip().upper()}
    field_names = {
        "QTY": "quantity",
        "NAME": "name",
        "PHONE": "phone",
        "PIN": "pincode",
        "ADDRESS": "address",
        "PAYMENT": "payment",
    }
    for part in parts[1:]:
        key, separator, value = part.partition(" ")
        normalized_key = key.rstrip(":").upper()
        if separator and normalized_key in field_names:
            result[field_names[normalized_key]] = value.strip()

    required = ("code", "quantity", "name", "phone", "pincode", "address", "payment")
    missing = [field for field in required if not result.get(field)]
    if missing:
        raise ValueError(f"Missing required order fields: {', '.join(missing)}")
    if not re.fullmatch(r"[A-Z0-9]+(?:-[A-Z0-9]+)*", result["code"]):
        raise ValueError("Product code must use uppercase letters, numbers, and hyphens")
    if not result["quantity"].isdigit() or not 1 <= int(result["quantity"]) <= 100:
        raise ValueError("Quantity must be between 1 and 100")
    if not re.fullmatch(r"\d{6}", result["pincode"]):
        raise ValueError("PIN must be exactly 6 digits")
    if result["payment"].upper() != "COD":
        raise ValueError("Only COD orders are currently supported")
    if len(result["address"]) > 500 or len(result["name"]) > 120:
        raise ValueError("Name or address is too long")
    result["quantity"] = str(int(result["quantity"]))
    result["payment"] = "COD"
    return result


def _message_event(direction: str, text: str) -> dict:
    return {"direction": direction, "text": text, "at": _now()}


def _save_inbound_order(
    business_id: str,
    message_id: str,
    sender: str,
    customer_name: str,
    text: str,
) -> dict:
    existing = (
        supabase.table("whatsapp_social_orders")
        .select("id")
        .eq("source_message_id", message_id)
        .limit(1)
        .execute()
    )
    if existing.data:
        return {"duplicate": True}

    parsed: dict[str, str] = {}
    validation: dict[str, Any] = {"valid": False, "errors": []}
    status = "failed_validation"
    product = None
    variant = None
    subtotal = delivery_fee = tax_amount = discount_amount = total_amount = 0.0
    phone = f"+{_digits(sender)}"
    name = customer_name or ""
    try:
        parsed = _parse_order_message(text)
        name = parsed["name"]
        if _digits(parsed["phone"]) != _digits(sender):
            raise ValueError("PHONE must match the WhatsApp number sending this order")
        variant_response = (
            supabase.table("product_variants")
            .select("*")
            .eq("business_id", business_id)
            .eq("code", parsed["code"])
            .eq("is_active", True)
            .limit(1)
            .execute()
        )
        if not variant_response.data:
            raise ValueError(f"No active product variant matches code {parsed['code']}")
        variant = variant_response.data[0]
        product_response = (
            supabase.table("products")
            .select("id,name,is_active")
            .eq("id", variant["product_id"])
            .eq("user_id", business_id)
            .eq("is_active", True)
            .limit(1)
            .execute()
        )
        if not product_response.data:
            raise ValueError("The product for this code is not available")
        product = product_response.data[0]
        quantity = int(parsed["quantity"])
        subtotal = round(float(variant.get("price") or 0) * quantity, 2)
        delivery_response = (
            supabase.table("delivery_settings")
            .select("*")
            .eq("business_id", business_id)
            .limit(1)
            .execute()
        )
        if not delivery_response.data:
            raise ValueError("The business has not configured delivery charges")
        quote = calculate_delivery_quote(
            delivery_response.data[0],
            parsed["pincode"],
            subtotal,
        )
        if not quote["is_deliverable"]:
            raise ValueError(quote["message"] or "This PIN is not deliverable")
        delivery_fee = round(float(quote["delivery_fee"]), 2)
        tax_amount = round(float(quote["tax"]), 2)
        discount_amount = round(float(quote["discount"]), 2)
        total_amount = round(
            subtotal + delivery_fee + tax_amount - discount_amount,
            2,
        )
        available_stock = int(variant.get("stock") or 0)
        if available_stock < quantity:
            status = "out_of_stock"
            validation = {
                "valid": False,
                "errors": [f"Only {available_stock} units are in stock"],
                "product_name": product["name"],
                "code": parsed["code"],
                "available_stock": available_stock,
                "delivery_days": quote.get("estimated_delivery_days"),
            }
        else:
            status = "awaiting_customer_confirmation"
            validation = {
                "valid": True,
                "errors": [],
                "product_name": product["name"],
                "code": parsed["code"],
                "available_stock": available_stock,
                "delivery_days": quote.get("estimated_delivery_days"),
            }
    except ValueError as error:
        validation = {"valid": False, "errors": [str(error)]}

    confirmation_code = secrets.token_hex(4).upper()
    row = {
        "business_id": business_id,
        "source_message_id": message_id,
        "confirmation_code": confirmation_code,
        "customer_phone": phone,
        "customer_name": name,
        "product_id": product.get("id") if product else None,
        "variant_id": variant.get("id") if variant else None,
        "product_code": parsed.get("code"),
        "quantity": int(parsed["quantity"]) if parsed.get("quantity", "").isdigit() else None,
        "delivery_pincode": parsed.get("pincode"),
        "shipping_address": parsed.get("address"),
        "payment_method": parsed.get("payment"),
        "status": status,
        "validation_result": validation,
        "subtotal": subtotal,
        "delivery_fee": delivery_fee,
        "tax_amount": tax_amount,
        "discount_amount": discount_amount,
        "total_amount": total_amount,
        "messages": [_message_event("inbound", text)],
        "created_at": _now(),
        "updated_at": _now(),
    }
    created = (
        supabase.table("whatsapp_social_orders")
        .insert(row)
        .select("*")
        .execute()
    )
    if not created.data:
        raise RuntimeError("WhatsApp order could not be saved")
    social_order = created.data[0]

    if status == "awaiting_customer_confirmation":
        config = _get_config(business_id) or {}
        templates = config.get("templates") or DEFAULT_TEMPLATES
        confirmation = _format_template(
            templates.get("confirmation", DEFAULT_TEMPLATES["confirmation"]),
            {
                "name": name,
                "order_id": confirmation_code,
                "total": f"{total_amount:.2f}",
            },
        )
        confirmation_instruction = f"CONFIRM {confirmation_code}"
        if confirmation_instruction.casefold() not in confirmation.casefold():
            confirmation += (
                f"\nTo confirm, reply {confirmation_instruction}."
            )
        try:
            _send_message(str(config["phone_number_id"]), phone, confirmation)
            events = row["messages"] + [_message_event("outbound", confirmation)]
            (
                supabase.table("whatsapp_social_orders")
                .update({"messages": events, "updated_at": _now()})
                .eq("id", social_order["id"])
                .eq("business_id", business_id)
                .execute()
            )
        except HTTPException as error:
            (
                supabase.table("whatsapp_social_orders")
                .update(
                    {
                        "status": "confirmation_failed",
                        "validation_result": {
                            **validation,
                            "message_error": str(error.detail),
                        },
                        "updated_at": _now(),
                    }
                )
                .eq("id", social_order["id"])
                .eq("business_id", business_id)
                .execute()
            )
    elif status in {"failed_validation", "out_of_stock"}:
        explanation = "; ".join(validation["errors"])
        try:
            _send_message(
                str((_get_config(business_id) or {})["phone_number_id"]),
                phone,
                f"We could not process your order: {explanation}. Please check the details and try again.",
            )
        except (HTTPException, KeyError) as error:
            error_message = (
                str(error.detail) if isinstance(error, HTTPException) else str(error)
            )
            latest = (
                supabase.table("whatsapp_social_orders")
                .select("messages,validation_result")
                .eq("id", social_order["id"])
                .eq("business_id", business_id)
                .limit(1)
                .execute()
            )
            if latest.data:
                latest_row = latest.data[0]
                messages = list(latest_row.get("messages") or [])
                messages.append(
                    _message_event(
                        "system",
                        f"Automatic customer reply failed: {error_message}",
                    )
                )
                validation_result = dict(
                    latest_row.get("validation_result") or validation
                )
                validation_result["message_error"] = error_message
                (
                    supabase.table("whatsapp_social_orders")
                    .update(
                        {
                            "messages": messages,
                            "validation_result": validation_result,
                            "updated_at": _now(),
                        }
                    )
                    .eq("id", social_order["id"])
                    .eq("business_id", business_id)
                    .execute()
                )
    return {"duplicate": False, "social_order_id": social_order["id"]}


def _create_order_after_confirmation(
    business_id: str,
    social_order: dict,
) -> dict:
    variant_response = (
        supabase.table("product_variants")
        .select("*")
        .eq("id", social_order["variant_id"])
        .eq("business_id", business_id)
        .eq("is_active", True)
        .limit(1)
        .execute()
    )
    if not variant_response.data:
        (
            supabase.table("whatsapp_social_orders")
            .update(
                {
                    "status": "failed_validation",
                    "validation_result": {
                        "valid": False,
                        "errors": ["Product code is no longer active"],
                    },
                    "updated_at": _now(),
                }
            )
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .execute()
        )
        raise HTTPException(status_code=409, detail="Product code is no longer active")
    variant = variant_response.data[0]
    quantity = int(social_order["quantity"])
    if int(variant.get("stock") or 0) < quantity:
        (
            supabase.table("whatsapp_social_orders")
            .update(
                {
                    "status": "out_of_stock",
                    "validation_result": {
                        "valid": False,
                        "errors": ["Stock changed before customer confirmation"],
                    },
                    "updated_at": _now(),
                }
            )
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .execute()
        )
        raise HTTPException(status_code=409, detail="Product is now out of stock")

    product_response = (
        supabase.table("products")
        .select("id")
        .eq("id", social_order["product_id"])
        .eq("user_id", business_id)
        .eq("is_active", True)
        .limit(1)
        .execute()
    )
    if not product_response.data:
        (
            supabase.table("whatsapp_social_orders")
            .update(
                {
                    "status": "failed_validation",
                    "validation_result": {
                        "valid": False,
                        "errors": ["Product is no longer available"],
                    },
                    "updated_at": _now(),
                }
            )
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .execute()
        )
        raise HTTPException(status_code=409, detail="Product is no longer available")

    current_subtotal = round(float(variant.get("price") or 0) * quantity, 2)
    if abs(current_subtotal - float(social_order["subtotal"] or 0)) > 0.01:
        (
            supabase.table("whatsapp_social_orders")
            .update(
                {
                    "status": "failed_validation",
                    "validation_result": {
                        "valid": False,
                        "errors": [
                            "Product price changed; ask the customer to review the new total"
                        ],
                    },
                    "updated_at": _now(),
                }
            )
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .execute()
        )
        raise HTTPException(status_code=409, detail="Product price changed")

    delivery_response = (
        supabase.table("delivery_settings")
        .select("*")
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    if not delivery_response.data:
        (
            supabase.table("whatsapp_social_orders")
            .update(
                {
                    "status": "failed_validation",
                    "validation_result": {
                        "valid": False,
                        "errors": ["Delivery settings changed; customer must review the quote"],
                    },
                    "updated_at": _now(),
                }
            )
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .execute()
        )
        raise HTTPException(
            status_code=409,
            detail="Delivery settings changed; customer must review the quote",
        )
    quote = calculate_delivery_quote(
        delivery_response.data[0],
        str(social_order.get("delivery_pincode") or ""),
        current_subtotal,
    )
    if not quote["is_deliverable"]:
        (
            supabase.table("whatsapp_social_orders")
            .update(
                {
                    "status": "failed_validation",
                    "validation_result": {
                        "valid": False,
                        "errors": [quote.get("message") or "PIN is no longer deliverable"],
                    },
                    "updated_at": _now(),
                }
            )
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .execute()
        )
        raise HTTPException(status_code=409, detail="PIN is no longer deliverable")
    current_total = (
        current_subtotal
        + float(quote["delivery_fee"])
        + float(quote["tax"])
        - float(quote["discount"])
    )
    if (
        abs(float(quote["delivery_fee"]) - float(social_order["delivery_fee"])) > 0.01
        or abs(float(quote["tax"]) - float(social_order["tax_amount"])) > 0.01
        or abs(float(quote["discount"]) - float(social_order["discount_amount"])) > 0.01
        or abs(current_total - float(social_order["total_amount"])) > 0.01
    ):
        (
            supabase.table("whatsapp_social_orders")
            .update(
                {
                    "status": "failed_validation",
                    "validation_result": {
                        "valid": False,
                        "errors": [
                            "Delivery total changed; ask the customer to review the new quote"
                        ],
                    },
                    "updated_at": _now(),
                }
            )
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .execute()
        )
        raise HTTPException(status_code=409, detail="Delivery total changed")

    customer_response = (
        supabase.table("customers")
        .select("id")
        .eq("user_id", business_id)
        .eq("phone", social_order["customer_phone"])
        .limit(1)
        .execute()
    )
    if customer_response.data:
        customer_id = str(customer_response.data[0]["id"])
    else:
        customer = (
            supabase.table("customers")
            .insert(
                {
                    "user_id": business_id,
                    "instagram_username": f"wa_{_digits(social_order['customer_phone'])}",
                    "display_name": social_order.get("customer_name"),
                    "phone": social_order["customer_phone"],
                    "is_vip": False,
                }
            )
            .select("id")
            .execute()
        )
        if not customer.data:
            raise HTTPException(status_code=500, detail="Customer could not be saved")
        customer_id = str(customer.data[0]["id"])

    inserted_order = (
        supabase.table("orders")
        .insert(
            {
                "user_id": business_id,
                "customer_id": customer_id,
                "status": "new",
                "source": "whatsapp",
                "notes": f"WhatsApp order {social_order['confirmation_code']}",
                "delivery_pincode": social_order.get("delivery_pincode"),
                "subtotal": social_order["subtotal"],
                "delivery_fee": social_order["delivery_fee"],
                "tax_amount": social_order["tax_amount"],
                "discount_amount": social_order["discount_amount"],
                "total_amount": social_order["total_amount"],
            }
        )
        .select("*")
        .execute()
    )
    if not inserted_order.data:
        raise HTTPException(status_code=500, detail="Order could not be created")
    order = inserted_order.data[0]
    order_id = str(order["id"])
    order_number = f"ORD-{order_id[:8].upper()}"
    supabase.table("orders").update({"order_number": order_number}).eq(
        "id", order_id
    ).eq("user_id", business_id).execute()

    try:
        items_response = supabase.table("order_items").insert(
            [
                {
                    "order_id": order_id,
                    "product_id": social_order["product_id"],
                    "quantity": quantity,
                    "unit_price": float(variant["price"]),
                    "variant_notes": social_order["product_code"],
                }
            ]
        ).select("*").execute()
        if not items_response.data:
            supabase.table("orders").delete().eq("id", order_id).eq(
                "user_id", business_id
            ).execute()
            raise HTTPException(status_code=500, detail="Order items could not be created")
    except Exception as error:
        supabase.table("orders").delete().eq("id", order_id).eq(
            "user_id", business_id
        ).execute()
        raise HTTPException(
            status_code=500,
            detail=f"Order items could not be created: {error}",
        ) from error

    create_activity_log(
        user_id=business_id,
        action="order_created",
        description=f"Created WhatsApp order worth ₹{float(social_order['total_amount']):.2f}",
        entity_type="order",
        entity_id=order_id,
        metadata={"total_amount": social_order["total_amount"], "source": "whatsapp"},
    )
    create_notification(
        user_id=business_id,
        title="New WhatsApp order",
        message=f"Order created successfully for ₹{float(social_order['total_amount']):.2f}",
        notification_type="success",
        entity_type="order",
        entity_id=order_id,
    )

    return {"id": order_id, "order_number": order_number, "customer_id": customer_id}


def _handle_customer_confirmation(
    business_id: str,
    message_id: str,
    sender: str,
    text: str,
) -> dict:
    match = re.fullmatch(r"\s*CONFIRM\s+([A-Z0-9]+)\s*", text, re.IGNORECASE)
    if not match:
        return {"ignored": True}
    lookup = (
        supabase.table("whatsapp_social_orders")
        .select("*")
        .eq("business_id", business_id)
        .eq("confirmation_code", match.group(1).upper())
        .eq("customer_phone", f"+{_digits(sender)}")
        .eq("status", "awaiting_customer_confirmation")
        .limit(1)
        .execute()
    )
    if not lookup.data:
        return {"ignored": True}
    pending = lookup.data[0]
    # Claim the pending record before creating an order so duplicate webhook
    # deliveries cannot create duplicate orders.
    claimed = (
        supabase.table("whatsapp_social_orders")
        .update(
            {
                "status": "confirmation_processing",
                "confirmation_message_id": message_id,
                "updated_at": _now(),
            }
        )
        .eq("id", pending["id"])
        .eq("business_id", business_id)
        .eq("status", "awaiting_customer_confirmation")
        .select("*")
        .execute()
    )
    if not claimed.data:
        return {"ignored": True}

    social_order = claimed.data[0]
    messages = list(social_order.get("messages") or [])
    messages.append(_message_event("inbound", text))
    try:
        order = _create_order_after_confirmation(business_id, social_order)
    except HTTPException as error:
        current = (
            supabase.table("whatsapp_social_orders")
            .select("status")
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .limit(1)
            .execute()
        )
        if current.data and current.data[0].get("status") in {
            "out_of_stock",
            "failed_validation",
        }:
            config = _get_config(business_id) or {}
            try:
                _send_message(
                    str(config.get("phone_number_id") or ""),
                    sender,
                    f"We could not confirm this order: {error.detail}. "
                    "Please review the details and send a new ORDER message.",
                )
            except HTTPException as send_error:
                messages.append(
                    _message_event(
                        "system",
                        f"Could not notify the customer: {send_error.detail}",
                    )
                )
                (
                    supabase.table("whatsapp_social_orders")
                    .update({"messages": messages, "updated_at": _now()})
                    .eq("id", social_order["id"])
                    .eq("business_id", business_id)
                    .execute()
                )
            return {"failed": True, "reason": error.detail}
        (
            supabase.table("whatsapp_social_orders")
            .update(
                {
                    "status": "awaiting_customer_confirmation",
                    "confirmation_message_id": None,
                    "updated_at": _now(),
                }
            )
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .eq("status", "confirmation_processing")
            .execute()
        )
        raise
    (
        supabase.table("whatsapp_social_orders")
        .update(
            {
                "status": "confirmed",
                "order_id": order["id"],
                "customer_confirmed_at": _now(),
                "messages": messages,
                "updated_at": _now(),
            }
        )
        .eq("id", social_order["id"])
        .eq("business_id", business_id)
        .execute()
    )
    config = _get_config(business_id) or {}
    try:
        _send_message(
            str(config["phone_number_id"]),
            sender,
            f"Thank you, your order {order['order_number']} is confirmed. "
            f"Total: ₹{float(social_order['total_amount']):.2f}.",
        )
    except HTTPException as error:
        messages.append(
            _message_event(
                "system",
                f"Order was created, but the WhatsApp reply failed: {error.detail}",
            )
        )
        (
            supabase.table("whatsapp_social_orders")
            .update(
                {
                    "messages": messages,
                    "validation_result": {
                        **(social_order.get("validation_result") or {}),
                        "message_error": str(error.detail),
                    },
                    "updated_at": _now(),
                }
            )
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .execute()
        )
    else:
        messages.append(
            _message_event(
                "outbound",
                f"Thank you, your order {order['order_number']} is confirmed. "
                f"Total: ₹{float(social_order['total_amount']):.2f}.",
            )
        )
        (
            supabase.table("whatsapp_social_orders")
            .update({"messages": messages, "updated_at": _now()})
            .eq("id", social_order["id"])
            .eq("business_id", business_id)
            .execute()
        )
    return {"confirmed": True, "order_id": order["id"]}


@router.get("/settings")
def get_whatsapp_settings(user=Depends(get_logged_in_user)):
    business_id = _business_id(user)
    return _config_response(_get_config(business_id), business_id)


@router.put("/settings")
def update_whatsapp_settings(
    payload: WhatsAppConfigUpdate,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    try:
        current = _get_config(business_id)
        settings_data = {**payload.model_dump(), "updated_at": _now()}
        query = supabase.table("whatsapp_order_settings")
        if current:
            response = (
                query.update(settings_data)
                .eq("business_id", business_id)
                .select("*")
                .execute()
            )
        else:
            response = (
                query.insert(
                    {
                        "business_id": business_id,
                        **settings_data,
                        "templates": DEFAULT_TEMPLATES,
                    }
                )
                .select("*")
                .execute()
            )
    except Exception as error:
        if "unique" in str(error).lower() or "duplicate key" in str(error).lower():
            raise HTTPException(
                status_code=409,
                detail="This WhatsApp Cloud API number is already connected to another business",
            ) from error
        raise HTTPException(
            status_code=500,
            detail=f"WhatsApp settings could not be saved: {error}",
        ) from error
    if not response.data:
        raise HTTPException(status_code=500, detail="WhatsApp settings could not be saved")
    return _config_response(response.data[0], business_id)


@router.put("/templates")
def update_whatsapp_templates(
    payload: MessageTemplatesUpdate,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    config = _get_config(business_id)
    if not config:
        try:
            response = (
                supabase.table("whatsapp_order_settings")
                .insert(
                    {
                        "business_id": business_id,
                        "templates": payload.model_dump(),
                        "is_enabled": False,
                        "updated_at": _now(),
                    }
                )
                .select("*")
                .execute()
            )
        except Exception as error:
            raise HTTPException(
                status_code=500,
                detail=f"WhatsApp message templates could not be saved: {error}",
            ) from error
        if not response.data:
            raise HTTPException(
                status_code=500,
                detail="WhatsApp templates could not be saved",
            )
        return _config_response(response.data[0], business_id)
    templates = payload.model_dump()
    try:
        response = (
            supabase.table("whatsapp_order_settings")
            .update({"templates": templates, "updated_at": _now()})
            .eq("business_id", business_id)
            .select("*")
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"WhatsApp message templates could not be saved: {error}",
        ) from error
    if not response.data:
        raise HTTPException(status_code=500, detail="WhatsApp templates could not be saved")
    return _config_response(response.data[0], business_id)


@router.get("")
def list_social_orders(
    status: str | None = Query(default=None),
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    query = (
        supabase.table("whatsapp_social_orders")
        .select("*")
        .eq("business_id", business_id)
        .order("created_at", desc=True)
        .limit(100)
    )
    if status:
        query = query.eq("status", status)
    try:
        response = query.execute()
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"WhatsApp orders could not be loaded: {error}",
        ) from error
    return {"orders": response.data or []}


@router.get("/{social_order_id}")
def get_social_order(
    social_order_id: str,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    response = (
        supabase.table("whatsapp_social_orders")
        .select("*")
        .eq("id", social_order_id)
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="WhatsApp order not found")
    return {"order": response.data[0]}


@router.post("/{social_order_id}/actions")
def act_on_social_order(
    social_order_id: str,
    payload: SocialOrderAction,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    response = (
        supabase.table("whatsapp_social_orders")
        .select("*")
        .eq("id", social_order_id)
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="WhatsApp order not found")
    social_order = response.data[0]
    if social_order["status"] not in {
        "awaiting_customer_confirmation",
        "confirmation_failed",
        "edit_requested",
        "failed_validation",
        "out_of_stock",
    }:
        raise HTTPException(status_code=409, detail="This WhatsApp order cannot be changed")

    config = _get_config(business_id) or {}
    if payload.action == "confirm_manually":
        if payload.customer_confirmed is not True:
            raise HTTPException(
                status_code=400,
                detail="Confirm that the customer agreed to place this order",
            )
        validation = social_order.get("validation_result") or {}
        if not validation.get("valid"):
            raise HTTPException(
                status_code=400,
                detail="Only a successfully validated order can be confirmed",
            )
        claimed = (
            supabase.table("whatsapp_social_orders")
            .update({"status": "confirmation_processing", "updated_at": _now()})
            .eq("id", social_order_id)
            .eq("business_id", business_id)
            .eq("status", social_order["status"])
            .select("*")
            .execute()
        )
        if not claimed.data:
            raise HTTPException(status_code=409, detail="WhatsApp order has changed")
        try:
            order = _create_order_after_confirmation(business_id, claimed.data[0])
        except HTTPException:
            current = (
                supabase.table("whatsapp_social_orders")
                .select("status")
                .eq("id", social_order_id)
                .eq("business_id", business_id)
                .limit(1)
                .execute()
            )
            if not current.data or current.data[0].get("status") not in {
                "out_of_stock",
                "failed_validation",
            }:
                (
                    supabase.table("whatsapp_social_orders")
                    .update(
                        {
                            "status": social_order["status"],
                            "updated_at": _now(),
                        }
                    )
                    .eq("id", social_order_id)
                    .eq("business_id", business_id)
                    .eq("status", "confirmation_processing")
                    .execute()
                )
            raise
        updated = (
            supabase.table("whatsapp_social_orders")
            .update(
                {
                    "status": "confirmed",
                    "order_id": order["id"],
                    "customer_confirmed_at": _now(),
                    "business_confirmed_by": business_id,
                    "updated_at": _now(),
                }
            )
            .eq("id", social_order_id)
            .eq("business_id", business_id)
            .select("*")
            .execute()
        )
        return {"order": updated.data[0] if updated.data else None, "created_order": order}

    if payload.action == "reject":
        status = "rejected"
        message = "We are unable to accept this order. Please contact the business if you need help."
    else:
        status = "edit_requested"
        message = "Please correct your order details and send the complete ORDER message again."
    if not config.get("is_enabled") or not config.get("phone_number_id"):
        raise HTTPException(
            status_code=409,
            detail="Enable WhatsApp ordering before sending a customer message",
        )
    _send_message(
        str(config.get("phone_number_id") or ""),
        str(social_order["customer_phone"]),
        message,
    )
    messages = list(social_order.get("messages") or [])
    messages.append(_message_event("outbound", message))
    updated = (
        supabase.table("whatsapp_social_orders")
        .update({"status": status, "messages": messages, "updated_at": _now()})
        .eq("id", social_order_id)
        .eq("business_id", business_id)
        .select("*")
        .execute()
    )
    if not updated.data:
        raise HTTPException(status_code=500, detail="WhatsApp order could not be updated")
    return {"order": updated.data[0]}


@webhook_router.get("")
def verify_whatsapp_webhook(
    mode: str | None = Query(default=None, alias="hub.mode"),
    verify_token: str | None = Query(default=None, alias="hub.verify_token"),
    challenge: str | None = Query(default=None, alias="hub.challenge"),
):
    expected = settings.WHATSAPP_VERIFY_TOKEN or settings.VERIFY_TOKEN
    if mode == "subscribe" and expected and hmac.compare_digest(verify_token or "", expected):
        return PlainTextResponse(content=challenge or "")
    raise HTTPException(status_code=403, detail="WhatsApp webhook verification failed")


@webhook_router.post("")
async def receive_whatsapp_webhook(
    request: Request,
    x_hub_signature_256: str | None = Header(default=None),
):
    raw_body = await request.body()
    app_secret = settings.META_APP_SECRET
    if not app_secret:
        raise HTTPException(
            status_code=503,
            detail="Meta app secret is not configured for webhook verification",
        )
    expected_signature = "sha256=" + hmac.new(
        app_secret.encode(),
        raw_body,
        hashlib.sha256,
    ).hexdigest()
    if not x_hub_signature_256 or not hmac.compare_digest(
        expected_signature,
        x_hub_signature_256,
    ):
        raise HTTPException(status_code=401, detail="Invalid WhatsApp webhook signature")

    try:
        payload = await request.json()
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid webhook JSON") from error

    for entry in payload.get("entry") or []:
        for change in entry.get("changes") or []:
            value = change.get("value") or {}
            metadata = value.get("metadata") or {}
            phone_number_id = str(metadata.get("phone_number_id") or "")
            if not phone_number_id:
                continue
            config_response = (
                supabase.table("whatsapp_order_settings")
                .select("*")
                .eq("phone_number_id", phone_number_id)
                .eq("is_enabled", True)
                .limit(1)
                .execute()
            )
            if not config_response.data:
                continue
            config = config_response.data[0]
            business_id = str(config["business_id"])
            contact_names = {
                str(contact.get("wa_id")): str(
                    (contact.get("profile") or {}).get("name") or ""
                )
                for contact in value.get("contacts") or []
            }
            for message in value.get("messages") or []:
                if message.get("type") != "text":
                    continue
                message_id = str(message.get("id") or "")
                sender = str(message.get("from") or "")
                text = str((message.get("text") or {}).get("body") or "").strip()
                if not message_id or not sender or not text:
                    continue
                if re.match(r"^ORDER\s+", text, re.IGNORECASE):
                    _save_inbound_order(
                        business_id,
                        message_id,
                        sender,
                        contact_names.get(sender, ""),
                        text,
                    )
                elif re.match(r"^CONFIRM\b", text, re.IGNORECASE):
                    _handle_customer_confirmation(
                        business_id,
                        message_id,
                        sender,
                        text,
                    )
    return {"status": "received"}
