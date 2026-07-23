from datetime import datetime, timezone
from html import escape
from typing import Any
from urllib.parse import quote
import re

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from core.auth import get_logged_in_user
from core.supabase import supabase
from services.email_service import send_email_via_resend
from services.invoice_service import generate_invoice_for_payment


router = APIRouter(prefix="/invoices", tags=["Invoices"])


class InvoiceGenerateRequest(BaseModel):
    payment_id: str | None = None
    order_id: str | None = None


class InvoiceMarkSentRequest(BaseModel):
    channel: str
    recipient: str | None = None
    subject: str | None = None
    message: str | None = None
    status: str = "sent"


class InvoiceSendEmailRequest(BaseModel):
    to: str | None = None
    subject: str | None = None
    message: str | None = None


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def to_float(value: Any) -> float:
    try:
        return float(value or 0)
    except Exception:
        return 0.0


def money(value: Any) -> str:
    return f"Rs. {to_float(value):.2f}"


def clean_phone_for_whatsapp(phone: str | None):
    if not phone:
        return None

    digits = re.sub(r"\D", "", phone)

    if not digits:
        return None

    if len(digits) == 10:
        return f"91{digits}"

    if len(digits) == 11 and digits.startswith("0"):
        return f"91{digits[1:]}"

    if len(digits) >= 10:
        return digits

    return None


def text_to_html(text: str):
    safe_text = escape(text)
    return safe_text.replace("\n", "<br/>")


def fetch_profile(user_id: str):
    response = (
        supabase.table("profiles")
        .select("*")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )

    if not response.data:
        return {
            "business_name": "OrdiFy Seller",
            "instagram_handle": None,
        }

    return response.data[0]


def fetch_customer(customer_id: str | None):
    if not customer_id:
        return None

    response = (
        supabase.table("customers")
        .select("*")
        .eq("id", customer_id)
        .limit(1)
        .execute()
    )

    if not response.data:
        return None

    return response.data[0]


def fetch_order_for_user(order_id: str, user_id: str):
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


def fetch_payment_for_user(payment_id: str, user_id: str):
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


def fetch_paid_payment_for_order(order_id: str, user_id: str):
    fetch_order_for_user(order_id, user_id)

    response = (
        supabase.table("payments")
        .select("*")
        .eq("order_id", order_id)
        .eq("user_id", user_id)
        .eq("status", "paid")
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )

    if not response.data:
        raise HTTPException(
            status_code=400,
            detail="No paid payment found. Mark payment as paid first.",
        )

    return response.data[0]


def fetch_invoice_for_user(invoice_id: str, user_id: str):
    invoice_response = (
        supabase.table("invoices")
        .select("*")
        .eq("id", invoice_id)
        .limit(1)
        .execute()
    )

    if not invoice_response.data:
        raise HTTPException(status_code=404, detail="Invoice not found")

    invoice = invoice_response.data[0]

    order = fetch_order_for_user(
        order_id=invoice["order_id"],
        user_id=user_id,
    )

    return invoice, order


def fetch_latest_invoice_for_order(order_id: str, user_id: str):
    order = fetch_order_for_user(order_id, user_id)

    invoice_response = (
        supabase.table("invoices")
        .select("*")
        .eq("order_id", order_id)
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )

    if not invoice_response.data:
        raise HTTPException(
            status_code=404,
            detail="No invoice found for this order",
        )

    return invoice_response.data[0], order


def build_invoice_share_payload(
    invoice: dict[str, Any],
    order: dict[str, Any],
    customer: dict[str, Any] | None,
    profile: dict[str, Any],
):
    pdf_url = invoice.get("pdf_url")

    if not pdf_url:
        raise HTTPException(
            status_code=500,
            detail="Invoice PDF URL is missing",
        )

    business_name = profile.get("business_name") or "OrdiFy Seller"
    instagram_handle = profile.get("instagram_handle")

    order_number = order.get("order_number") or order.get("id")
    total_amount = order.get("total_amount")

    customer_name = "Customer"
    customer_email = None
    customer_phone = None
    customer_instagram = None

    if customer:
        customer_name = (
            customer.get("display_name")
            or customer.get("instagram_username")
            or "Customer"
        )
        customer_email = customer.get("email")
        customer_phone = customer.get("phone")
        customer_instagram = customer.get("instagram_username")

    whatsapp_message = (
        f"Hi {customer_name},\n\n"
        f"Your invoice for order {order_number} from {business_name} is ready.\n\n"
        f"Amount: {money(total_amount)}\n"
        f"Invoice PDF: {pdf_url}\n\n"
        f"Thank you for shopping with us."
    )

    if instagram_handle:
        whatsapp_message += f"\n\n- {business_name} (@{instagram_handle})"
    else:
        whatsapp_message += f"\n\n- {business_name}"

    whatsapp_phone = clean_phone_for_whatsapp(customer_phone)

    whatsapp_url = None

    if whatsapp_phone:
        whatsapp_url = f"https://wa.me/{whatsapp_phone}?text={quote(whatsapp_message)}"

    email_subject = f"Invoice for Order {order_number} - {business_name}"

    email_body = (
        f"Hi {customer_name},\n\n"
        f"Thank you for your order.\n\n"
        f"Order Number: {order_number}\n"
        f"Amount: {money(total_amount)}\n"
        f"Invoice PDF: {pdf_url}\n\n"
        f"Regards,\n"
        f"{business_name}"
    )

    return {
        "invoice": {
            "id": invoice.get("id"),
            "order_id": invoice.get("order_id"),
            "payment_id": invoice.get("payment_id"),
            "pdf_url": pdf_url,
            "sent_at": invoice.get("sent_at"),
            "created_at": invoice.get("created_at"),
        },
        "order": {
            "id": order.get("id"),
            "order_number": order_number,
            "status": order.get("status"),
            "total_amount": total_amount,
            "source": order.get("source"),
        },
        "customer": {
            "id": customer.get("id") if customer else None,
            "name": customer_name,
            "email": customer_email,
            "phone": customer_phone,
            "instagram_username": customer_instagram,
        },
        "whatsapp": {
            "phone": whatsapp_phone,
            "message": whatsapp_message,
            "url": whatsapp_url,
            "can_open_directly": whatsapp_url is not None,
        },
        "email": {
            "to": customer_email,
            "subject": email_subject,
            "body": email_body,
            "can_send_directly": customer_email is not None,
        },
    }


def build_invoice_email_html(
    business_name: str,
    customer_name: str,
    order_number: str,
    total_amount: Any,
    pdf_url: str,
    message: str,
):
    safe_business_name = escape(business_name)
    safe_customer_name = escape(customer_name)
    safe_order_number = escape(str(order_number))
    safe_total = escape(money(total_amount))
    safe_pdf_url = escape(pdf_url)
    safe_message_html = text_to_html(message)

    return f"""
    <div style="font-family: Arial, sans-serif; background: #f6f7f9; padding: 24px;">
      <div style="max-width: 640px; margin: 0 auto; background: #ffffff; border-radius: 14px; overflow: hidden; border: 1px solid #e5e7eb;">
        <div style="background: #0B3D2E; color: white; padding: 22px;">
          <h2 style="margin: 0;">{safe_business_name}</h2>
          <p style="margin: 6px 0 0;">Invoice for your order</p>
        </div>

        <div style="padding: 24px; color: #111827;">
          <p>Hi {safe_customer_name},</p>

          <p>{safe_message_html}</p>

          <div style="background: #f2fbf6; border: 1px solid #bfe8cf; border-radius: 12px; padding: 16px; margin: 20px 0;">
            <p style="margin: 0 0 8px;"><strong>Order Number:</strong> {safe_order_number}</p>
            <p style="margin: 0;"><strong>Amount:</strong> {safe_total}</p>
          </div>

          <p>
            <a href="{safe_pdf_url}" style="display: inline-block; background: #0B3D2E; color: white; text-decoration: none; padding: 12px 18px; border-radius: 10px;">
              Open Invoice PDF
            </a>
          </p>

          <p style="font-size: 13px; color: #6b7280;">
            If the button does not work, copy this link:<br/>
            <a href="{safe_pdf_url}">{safe_pdf_url}</a>
          </p>

          <p>Regards,<br/>{safe_business_name}</p>
        </div>
      </div>
    </div>
    """


def create_message_log(
    user_id: str,
    customer_id: str | None,
    order_id: str,
    invoice_id: str,
    channel: str,
    recipient: str | None,
    subject: str | None,
    message: str | None,
    status: str,
):
    if channel not in ["whatsapp", "email", "manual"]:
        raise HTTPException(
            status_code=400,
            detail="Channel must be whatsapp, email, or manual",
        )

    if status not in ["prepared", "sent", "failed"]:
        raise HTTPException(
            status_code=400,
            detail="Status must be prepared, sent, or failed",
        )

    try:
        response = (
            supabase.table("message_logs")
            .insert(
                {
                    "user_id": user_id,
                    "customer_id": customer_id,
                    "order_id": order_id,
                    "invoice_id": invoice_id,
                    "channel": channel,
                    "recipient": recipient,
                    "subject": subject,
                    "message": message,
                    "status": status,
                    "sent_at": now_iso() if status == "sent" else None,
                }
            )
            .select()
            .execute()
        )

        if response.data:
            return response.data[0]
    except Exception:
        return None

    return None


def update_invoice_sent_at(invoice_id: str):
    response = (
        supabase.table("invoices")
        .update({"sent_at": now_iso()})
        .eq("id", invoice_id)
        .select()
        .execute()
    )

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Invoice sent_at could not be updated",
        )

    return response.data[0]


@router.post("/generate")
def generate_invoice(
    payload: InvoiceGenerateRequest,
    user=Depends(get_logged_in_user),
):
    user_id = str(user.id)

    if payload.payment_id:
        payment = fetch_payment_for_user(payload.payment_id, user_id)

        if payment.get("status") != "paid":
            raise HTTPException(
                status_code=400,
                detail="Invoice can be generated only after payment is paid.",
            )

        return generate_invoice_for_payment(
            payment_id=payload.payment_id,
            user_id=user_id,
        )

    if payload.order_id:
        payment = fetch_paid_payment_for_order(payload.order_id, user_id)

        return generate_invoice_for_payment(
            payment_id=payment["id"],
            user_id=user_id,
        )

    raise HTTPException(
        status_code=400,
        detail="Send either payment_id or order_id",
    )


@router.get("/order/{order_id}")
def get_invoices_for_order(
    order_id: str,
    user=Depends(get_logged_in_user),
):
    user_id = str(user.id)

    fetch_order_for_user(order_id, user_id)

    invoice_response = (
        supabase.table("invoices")
        .select("*")
        .eq("order_id", order_id)
        .order("created_at", desc=True)
        .execute()
    )

    invoices = invoice_response.data or []

    return {
        "invoices": invoices,
        "count": len(invoices),
    }


@router.get("/{invoice_id}/share")
def get_invoice_share_payload(
    invoice_id: str,
    user=Depends(get_logged_in_user),
):
    user_id = str(user.id)

    invoice, order = fetch_invoice_for_user(invoice_id, user_id)
    customer = fetch_customer(order.get("customer_id"))
    profile = fetch_profile(user_id)

    return build_invoice_share_payload(
        invoice=invoice,
        order=order,
        customer=customer,
        profile=profile,
    )


@router.get("/order/{order_id}/latest-share")
def get_latest_invoice_share_payload_for_order(
    order_id: str,
    user=Depends(get_logged_in_user),
):
    user_id = str(user.id)

    invoice, order = fetch_latest_invoice_for_order(order_id, user_id)
    customer = fetch_customer(order.get("customer_id"))
    profile = fetch_profile(user_id)

    return build_invoice_share_payload(
        invoice=invoice,
        order=order,
        customer=customer,
        profile=profile,
    )


@router.post("/{invoice_id}/mark-sent")
def mark_invoice_as_sent(
    invoice_id: str,
    payload: InvoiceMarkSentRequest,
    user=Depends(get_logged_in_user),
):
    user_id = str(user.id)

    invoice, order = fetch_invoice_for_user(invoice_id, user_id)
    customer = fetch_customer(order.get("customer_id"))

    message_log = create_message_log(
        user_id=user_id,
        customer_id=customer.get("id") if customer else None,
        order_id=order["id"],
        invoice_id=invoice["id"],
        channel=payload.channel,
        recipient=payload.recipient,
        subject=payload.subject,
        message=payload.message,
        status=payload.status,
    )

    updated_invoice = invoice

    if payload.status == "sent":
        updated_invoice = update_invoice_sent_at(invoice["id"])

    return {
        "message": "Invoice delivery status saved successfully",
        "invoice": updated_invoice,
        "message_log": message_log,
    }


@router.post("/{invoice_id}/send-email")
def send_invoice_email(
    invoice_id: str,
    payload: InvoiceSendEmailRequest,
    user=Depends(get_logged_in_user),
):
    user_id = str(user.id)

    invoice, order = fetch_invoice_for_user(invoice_id, user_id)
    customer = fetch_customer(order.get("customer_id"))
    profile = fetch_profile(user_id)

    share_payload = build_invoice_share_payload(
        invoice=invoice,
        order=order,
        customer=customer,
        profile=profile,
    )

    customer_info = share_payload["customer"]
    email_info = share_payload["email"]
    invoice_info = share_payload["invoice"]
    order_info = share_payload["order"]

    to_email = payload.to or email_info.get("to")

    if not to_email:
        raise HTTPException(
            status_code=400,
            detail="Customer email is missing.",
        )

    subject = payload.subject or email_info["subject"]
    message = payload.message or email_info["body"]

    business_name = profile.get("business_name") or "OrdiFy Seller"
    customer_name = customer_info.get("name") or "Customer"

    html = build_invoice_email_html(
        business_name=business_name,
        customer_name=customer_name,
        order_number=order_info["order_number"],
        total_amount=order_info["total_amount"],
        pdf_url=invoice_info["pdf_url"],
        message=message,
    )

    safe_email_key = re.sub(r"[^a-zA-Z0-9]", "-", to_email)[:80]
    idempotency_key = f"ordify-invoice-{invoice_id}-{safe_email_key}"

    email_result = send_email_via_resend(
        to_email=to_email,
        subject=subject,
        html=html,
        text=message,
        idempotency_key=idempotency_key,
    )

    message_log = create_message_log(
        user_id=user_id,
        customer_id=customer_info.get("id"),
        order_id=order["id"],
        invoice_id=invoice["id"],
        channel="email",
        recipient=to_email,
        subject=subject,
        message=message,
        status="sent",
    )

    updated_invoice = update_invoice_sent_at(invoice["id"])

    return {
        "message": "Invoice email sent successfully",
        "invoice": updated_invoice,
        "message_log": message_log,
        "email_result": email_result,
    }


@router.get("/{invoice_id}/message-logs")
def get_invoice_message_logs(
    invoice_id: str,
    user=Depends(get_logged_in_user),
):
    user_id = str(user.id)

    fetch_invoice_for_user(invoice_id, user_id)

    try:
        response = (
            supabase.table("message_logs")
            .select("*")
            .eq("invoice_id", invoice_id)
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )

        logs = response.data or []
    except Exception:
        logs = []

    return {
        "logs": logs,
        "count": len(logs),
    }