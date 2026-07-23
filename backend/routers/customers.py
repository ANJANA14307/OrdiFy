from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from core.auth import get_logged_in_user
from core.supabase import supabase


router = APIRouter(prefix="/customers", tags=["Customers"])


class CustomerCreate(BaseModel):
    instagram_username: str = Field(..., min_length=1, max_length=80)
    display_name: Optional[str] = Field(default=None, max_length=120)
    email: Optional[str] = Field(default=None, max_length=160)
    phone: Optional[str] = Field(default=None, max_length=40)
    is_vip: bool = False


class CustomerUpdate(BaseModel):
    instagram_username: Optional[str] = Field(default=None, min_length=1, max_length=80)
    display_name: Optional[str] = Field(default=None, max_length=120)
    email: Optional[str] = Field(default=None, max_length=160)
    phone: Optional[str] = Field(default=None, max_length=40)
    is_vip: Optional[bool] = None


def _uid(user) -> str:
    return str(user.id)


def _clean_optional(value: str | None) -> str | None:
    if value is None:
        return None

    cleaned = value.strip()

    return cleaned or None


def _clean_instagram(value: str) -> str:
    cleaned = value.strip().replace("@", "")

    if not cleaned:
        raise HTTPException(
            status_code=400,
            detail="Instagram username is required",
        )

    return cleaned


@router.get("")
def get_customers(
    search: Optional[str] = Query(default=None),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=100, ge=1, le=200),
    user=Depends(get_logged_in_user),
):
    user_id = _uid(user)

    start = (page - 1) * limit
    end = start + limit - 1

    try:
        response = (
            supabase.table("customers")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .range(start, end)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Customers could not be fetched: {str(exc)}",
        )

    customers = response.data or []

    if search is not None and search.strip():
        search_text = search.strip().lower()

        customers = [
            customer
            for customer in customers
            if search_text in str(customer.get("instagram_username") or "").lower()
            or search_text in str(customer.get("display_name") or "").lower()
            or search_text in str(customer.get("email") or "").lower()
            or search_text in str(customer.get("phone") or "").lower()
        ]

    vip_count = 0
    total_orders = 0
    total_spent = 0.0

    for customer in customers:
        if customer.get("is_vip") is True:
            vip_count += 1

        total_orders += int(customer.get("total_orders") or 0)
        total_spent += float(customer.get("total_spent") or 0)

    return {
        "page": page,
        "limit": limit,
        "customers": customers,
        "count": len(customers),
        "vip_count": vip_count,
        "total_orders": total_orders,
        "total_spent": total_spent,
    }


@router.post("")
def create_customer(
    payload: CustomerCreate,
    user=Depends(get_logged_in_user),
):
    user_id = _uid(user)

    instagram_username = _clean_instagram(payload.instagram_username)

    try:
        existing_response = (
            supabase.table("customers")
            .select("id")
            .eq("user_id", user_id)
            .eq("instagram_username", instagram_username)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Customer duplicate check failed: {str(exc)}",
        )

    if existing_response.data:
        raise HTTPException(
            status_code=400,
            detail="Customer with this Instagram username already exists",
        )

    customer_data = {
        "user_id": user_id,
        "instagram_username": instagram_username,
        "display_name": _clean_optional(payload.display_name),
        "email": _clean_optional(payload.email),
        "phone": _clean_optional(payload.phone),
        "is_vip": payload.is_vip,
    }

    try:
        response = (
            supabase.table("customers")
            .insert(customer_data)
            .select()
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create customer: {str(exc)}",
        )

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Failed to create customer",
        )

    return {
        "message": "Customer created successfully",
        "customer": response.data[0],
    }


@router.patch("/{customer_id}")
def update_customer(
    customer_id: str,
    payload: CustomerUpdate,
    user=Depends(get_logged_in_user),
):
    user_id = _uid(user)

    try:
        existing_response = (
            supabase.table("customers")
            .select("*")
            .eq("id", customer_id)
            .eq("user_id", user_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Customer lookup failed: {str(exc)}",
        )

    if not existing_response.data:
        raise HTTPException(
            status_code=404,
            detail="Customer not found",
        )

    update_data = payload.model_dump(exclude_unset=True)

    if "instagram_username" in update_data and update_data["instagram_username"] is not None:
        username = _clean_instagram(update_data["instagram_username"])

        try:
            duplicate_response = (
                supabase.table("customers")
                .select("id")
                .eq("user_id", user_id)
                .eq("instagram_username", username)
                .neq("id", customer_id)
                .execute()
            )
        except Exception as exc:
            raise HTTPException(
                status_code=500,
                detail=f"Customer duplicate check failed: {str(exc)}",
            )

        if duplicate_response.data:
            raise HTTPException(
                status_code=400,
                detail="Another customer already uses this Instagram username",
            )

        update_data["instagram_username"] = username

    if "display_name" in update_data:
        update_data["display_name"] = _clean_optional(update_data.get("display_name"))

    if "email" in update_data:
        update_data["email"] = _clean_optional(update_data.get("email"))

    if "phone" in update_data:
        update_data["phone"] = _clean_optional(update_data.get("phone"))

    if not update_data:
        raise HTTPException(
            status_code=400,
            detail="No fields to update",
        )

    try:
        response = (
            supabase.table("customers")
            .update(update_data)
            .eq("id", customer_id)
            .eq("user_id", user_id)
            .select()
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update customer: {str(exc)}",
        )

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Failed to update customer",
        )

    return {
        "message": "Customer updated successfully",
        "customer": response.data[0],
    }


@router.delete("/{customer_id}")
def delete_customer(
    customer_id: str,
    user=Depends(get_logged_in_user),
):
    user_id = _uid(user)

    try:
        existing_response = (
            supabase.table("customers")
            .select("*")
            .eq("id", customer_id)
            .eq("user_id", user_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Customer lookup failed: {str(exc)}",
        )

    if not existing_response.data:
        raise HTTPException(
            status_code=404,
            detail="Customer not found",
        )

    try:
        order_response = (
            supabase.table("orders")
            .select("id")
            .eq("customer_id", customer_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Customer order check failed: {str(exc)}",
        )

    if order_response.data:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete customer with existing orders",
        )

    try:
        supabase.table("customers").delete().eq("id", customer_id).eq(
            "user_id", user_id
        ).execute()
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete customer: {str(exc)}",
        )

    return {
        "message": "Customer deleted successfully",
    }