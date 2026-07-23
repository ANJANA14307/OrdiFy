from fastapi import APIRouter, Depends

from core.auth import get_logged_in_user
from core.supabase import supabase


router = APIRouter(prefix="/activity", tags=["Activity"])


@router.get("")
def get_activity_logs(
    entity_type: str | None = None,
    entity_id: str | None = None,
    limit: int = 50,
    user=Depends(get_logged_in_user),
):
    query = (
        supabase.table("activity_logs")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", desc=True)
        .limit(limit)
    )

    if entity_type:
        query = query.eq("entity_type", entity_type)

    if entity_id:
        query = query.eq("entity_id", entity_id)

    response = query.execute()

    logs = response.data or []

    return {
        "logs": logs,
        "count": len(logs),
    }


@router.get("/order/{order_id}")
def get_order_activity_logs(
    order_id: str,
    user=Depends(get_logged_in_user),
):
    response = (
        supabase.table("activity_logs")
        .select("*")
        .eq("user_id", user.id)
        .eq("entity_type", "order")
        .eq("entity_id", order_id)
        .order("created_at", desc=True)
        .execute()
    )

    logs = response.data or []

    return {
        "logs": logs,
        "count": len(logs),
    }


@router.get("/invoice/{invoice_id}")
def get_invoice_activity_logs(
    invoice_id: str,
    user=Depends(get_logged_in_user),
):
    response = (
        supabase.table("activity_logs")
        .select("*")
        .eq("user_id", user.id)
        .eq("entity_type", "invoice")
        .eq("entity_id", invoice_id)
        .order("created_at", desc=True)
        .execute()
    )

    logs = response.data or []

    return {
        "logs": logs,
        "count": len(logs),
    }