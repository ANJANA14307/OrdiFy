from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional
import tempfile
import httpx

import cloudinary
import cloudinary.uploader
from fastapi import HTTPException
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)

from core.config import settings
from core.supabase import supabase


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


def money(value: Any) -> str:
    amount = to_float(value)
    return f"Rs. {amount:.2f}"


def configure_cloudinary():
    if (
        not settings.CLOUDINARY_CLOUD_NAME
        or not settings.CLOUDINARY_API_KEY
        or not settings.CLOUDINARY_API_SECRET
    ):
        raise HTTPException(
            status_code=500,
            detail="Cloudinary is not configured in .env",
        )

    cloudinary.config(
        cloud_name=settings.CLOUDINARY_CLOUD_NAME,
        api_key=settings.CLOUDINARY_API_KEY,
        api_secret=settings.CLOUDINARY_API_SECRET,
        secure=True,
    )


def fetch_profile(user_id: str):
    response = (
        supabase.table("profiles")
        .select("*")
        .eq("id", user_id)
        .execute()
    )

    if not response.data:
        return {
            "business_name": "OrdiFy Seller",
            "instagram_handle": "ordify_seller",
        }

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


def fetch_order(order_id: str, user_id: str):
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


def fetch_payment(payment_id: str, user_id: str):
    response = (
        supabase.table("payments")
        .select("*")
        .eq("id", payment_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail="Payment not found",
        )

    return response.data[0]


def fetch_order_items_with_products(order_id: str):
    item_response = (
        supabase.table("order_items")
        .select("*")
        .eq("order_id", order_id)
        .execute()
    )

    items = item_response.data or []
    detailed_items = []

    for item in items:
        product = None
        product_id = item.get("product_id")

        if product_id:
            product_response = (
                supabase.table("products")
                .select("*")
                .eq("id", product_id)
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

    return detailed_items


def existing_invoice_for_payment(payment_id: str):
    response = (
        supabase.table("invoices")
        .select("*")
        .eq("payment_id", payment_id)
        .limit(1)
        .execute()
    )

    if not response.data:
        return None

    return response.data[0]


def build_invoice_pdf(
    pdf_path: str,
    profile: dict[str, Any],
    customer: Optional[dict[str, Any]],
    order: dict[str, Any],
    payment: dict[str, Any],
    items: list[dict[str, Any]],
):
    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        "OrdifyTitle",
        parent=styles["Title"],
        fontSize=22,
        leading=26,
        textColor=colors.HexColor("#0B3D2E"),
        spaceAfter=12,
    )

    heading_style = ParagraphStyle(
        "OrdifyHeading",
        parent=styles["Heading2"],
        fontSize=13,
        leading=16,
        textColor=colors.HexColor("#0B3D2E"),
        spaceAfter=8,
    )

    normal_style = ParagraphStyle(
        "OrdifyNormal",
        parent=styles["Normal"],
        fontSize=9,
        leading=13,
        textColor=colors.HexColor("#222222"),
    )

    muted_style = ParagraphStyle(
        "OrdifyMuted",
        parent=styles["Normal"],
        fontSize=8,
        leading=11,
        textColor=colors.HexColor("#666666"),
    )

    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=A4,
        rightMargin=18 * mm,
        leftMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
    )

    story = []

    order_number = order.get("order_number") or order.get("id")
    invoice_number = f"INV-{order_number}"
    invoice_date = datetime.now(timezone.utc).strftime("%d %b %Y")

    business_name = profile.get("business_name") or "OrdiFy Seller"
    instagram_handle = profile.get("instagram_handle") or profile.get("instagram_username") or ""

    customer_name = "Customer"
    customer_contact = ""

    if customer:
        customer_name = (
            customer.get("display_name")
            or customer.get("instagram_username")
            or "Customer"
        )
        customer_contact_parts = []

        if customer.get("instagram_username"):
            customer_contact_parts.append(f"Instagram: @{customer.get('instagram_username')}")

        if customer.get("email"):
            customer_contact_parts.append(f"Email: {customer.get('email')}")

        if customer.get("phone"):
            customer_contact_parts.append(f"Phone: {customer.get('phone')}")

        customer_contact = "<br/>".join(customer_contact_parts)

    story.append(Paragraph("OrdiFy Invoice", title_style))
    story.append(
        Paragraph(
            "Inventory • Orders • Customers • Payments",
            muted_style,
        )
    )
    story.append(Spacer(1, 10))

    top_table = Table(
        [
            [
                Paragraph(
                    f"<b>Seller</b><br/>{business_name}<br/>"
                    f"{('@' + instagram_handle) if instagram_handle else ''}",
                    normal_style,
                ),
                Paragraph(
                    f"<b>Invoice</b><br/>{invoice_number}<br/>"
                    f"Date: {invoice_date}<br/>"
                    f"Order: {order_number}",
                    normal_style,
                ),
            ]
        ],
        colWidths=[90 * mm, 70 * mm],
    )

    top_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F2FBF6")),
                ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#BFE8CF")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("PADDING", (0, 0), (-1, -1), 10),
            ]
        )
    )

    story.append(top_table)
    story.append(Spacer(1, 14))

    story.append(Paragraph("Bill To", heading_style))
    story.append(
        Paragraph(
            f"<b>{customer_name}</b><br/>{customer_contact if customer_contact else 'Customer details not available'}",
            normal_style,
        )
    )
    story.append(Spacer(1, 14))

    item_rows = [
        [
            Paragraph("<b>Item</b>", normal_style),
            Paragraph("<b>Qty</b>", normal_style),
            Paragraph("<b>Unit Price</b>", normal_style),
            Paragraph("<b>Total</b>", normal_style),
        ]
    ]

    subtotal = 0.0

    for item in items:
        product = item.get("product") or {}
        product_name = product.get("name") or "Product"

        quantity = to_int(item.get("quantity"))
        unit_price = to_float(item.get("unit_price"))
        line_total = quantity * unit_price
        subtotal += line_total

        item_note = item.get("variant_notes")

        if item_note:
            product_name = f"{product_name}<br/><font color='#666666'>{item_note}</font>"

        item_rows.append(
            [
                Paragraph(product_name, normal_style),
                Paragraph(str(quantity), normal_style),
                Paragraph(money(unit_price), normal_style),
                Paragraph(money(line_total), normal_style),
            ]
        )

    if len(item_rows) == 1:
        item_rows.append(
            [
                Paragraph("No items found", normal_style),
                Paragraph("-", normal_style),
                Paragraph("-", normal_style),
                Paragraph("-", normal_style),
            ]
        )

    items_table = Table(
        item_rows,
        colWidths=[78 * mm, 20 * mm, 32 * mm, 32 * mm],
    )

    items_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0B3D2E")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#D9EDE2")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("PADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )

    story.append(items_table)
    story.append(Spacer(1, 14))

    order_total = to_float(order.get("total_amount")) or subtotal
    payment_gateway = payment.get("gateway") or "payment"
    payment_status = payment.get("status") or "pending"

    total_table = Table(
        [
            ["Subtotal", money(subtotal)],
            ["Total", money(order_total)],
            ["Payment Mode", payment_gateway.upper()],
            ["Payment Status", payment_status.upper()],
        ],
        colWidths=[110 * mm, 52 * mm],
    )

    total_table.setStyle(
        TableStyle(
            [
                ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                ("BACKGROUND", (0, 1), (-1, 1), colors.HexColor("#E9FFF1")),
                ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#BFE8CF")),
                ("PADDING", (0, 0), (-1, -1), 8),
                ("FONTNAME", (0, 1), (-1, 1), "Helvetica-Bold"),
            ]
        )
    )

    story.append(total_table)
    story.append(Spacer(1, 18))

    story.append(
        Paragraph(
            "This invoice was generated by OrdiFy. Thank you for your order.",
            muted_style,
        )
    )

    doc.build(story)


def upload_invoice_to_cloudinary(pdf_path: str, public_id: str):
    bucket_name = "invoices"

    clean_public_id = public_id.replace("\\", "-").replace("/", "-")

    if not clean_public_id.lower().endswith(".pdf"):
        clean_public_id = f"{clean_public_id}.pdf"

    storage_path = f"ordify/{clean_public_id}"

    upload_url = (
        f"{settings.SUPABASE_URL}/storage/v1/object/"
        f"{bucket_name}/{storage_path}"
    )

    public_url = (
        f"{settings.SUPABASE_URL}/storage/v1/object/public/"
        f"{bucket_name}/{storage_path}"
    )

    with open(pdf_path, "rb") as pdf_file:
        pdf_bytes = pdf_file.read()

    if not pdf_bytes:
        raise HTTPException(
            status_code=500,
            detail="Generated invoice PDF is empty before upload",
        )

    headers = {
        "Authorization": f"Bearer {settings.SUPABASE_SECRET_KEY}",
        "apikey": settings.SUPABASE_SECRET_KEY,
        "Content-Type": "application/pdf",
        "x-upsert": "true",
    }

    response = httpx.post(
        upload_url,
        headers=headers,
        content=pdf_bytes,
        timeout=30,
    )

    if response.status_code not in [200, 201]:
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Supabase invoice PDF upload failed",
                "status_code": response.status_code,
                "response": response.text,
            },
        )

    return public_url


def insert_invoice_row(payment_id: str, order_id: str, pdf_url: str):
    response = (
        supabase.table("invoices")
        .insert(
            {
                "payment_id": payment_id,
                "order_id": order_id,
                "pdf_url": pdf_url,
                "sent_at": None,
            }
        )
        .execute()
    )

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Invoice row could not be created",
        )

    return response.data[0]


def generate_invoice_for_payment(payment_id: str, user_id: str):
    payment = fetch_payment(payment_id=payment_id, user_id=user_id)

    if payment.get("status") != "paid":
        raise HTTPException(
            status_code=400,
            detail="Invoice can be generated only for paid payments",
        )

    existing_invoice = existing_invoice_for_payment(payment_id)

    if existing_invoice and existing_invoice.get("pdf_url"):
        return {
            "message": "Existing invoice returned",
            "invoice": existing_invoice,
            "pdf_url": existing_invoice.get("pdf_url"),
        }

    order = fetch_order(order_id=payment["order_id"], user_id=user_id)
    customer = fetch_customer(order.get("customer_id"))
    profile = fetch_profile(user_id)
    items = fetch_order_items_with_products(order["id"])

    order_number = order.get("order_number") or order.get("id")
    safe_order_number = str(order_number).replace("/", "-").replace("\\", "-")
    public_id = f"invoice_{safe_order_number}_{payment_id}.pdf"
    temp_dir = tempfile.gettempdir()
    pdf_path = str(Path(temp_dir) / f"{public_id}.pdf")

    build_invoice_pdf(
        pdf_path=pdf_path,
        profile=profile,
        customer=customer,
        order=order,
        payment=payment,
        items=items,
    )

    pdf_url = upload_invoice_to_cloudinary(
        pdf_path=pdf_path,
        public_id=public_id,
    )

    invoice = insert_invoice_row(
        payment_id=payment_id,
        order_id=order["id"],
        pdf_url=pdf_url,
    )

    return {
        "message": "Invoice generated successfully",
        "invoice": invoice,
        "pdf_url": pdf_url,
    }