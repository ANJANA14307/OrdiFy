from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from core.auth import get_logged_in_user
from core.supabase import supabase
from services.invoice_service import generate_invoice_for_payment


router = APIRouter(prefix="/invoices", tags=["Invoices"])


class InvoiceGenerateRequest(BaseModel):
    payment_id: str


@router.post("/generate")
def generate_invoice(
    payload: InvoiceGenerateRequest,
    user=Depends(get_logged_in_user),
):
    return generate_invoice_for_payment(
        payment_id=payload.payment_id,
        user_id=user.id,
    )


@router.get("/order/{order_id}")
def get_invoices_for_order(
    order_id: str,
    user=Depends(get_logged_in_user),
):
    order_response = (
        supabase.table("orders")
        .select("id")
        .eq("id", order_id)
        .eq("user_id", user.id)
        .execute()
    )

    if not order_response.data:
        raise HTTPException(
            status_code=404,
            detail="Order not found",
        )

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