from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import Optional

from core.auth import get_logged_in_user
from core.supabase import supabase


router = APIRouter(prefix="/customers", tags=["Customers"])


class CustomerCreate(BaseModel):
    instagram_username: str
    display_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None


class CustomerUpdate(BaseModel):
    instagram_username: Optional[str] = None
    display_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    is_vip: Optional[bool] = None


def get_user_id(user):
    return user.id


@router.get("")
def get_customers(
    search: Optional[str] = Query(default=None),
    user=Depends(get_logged_in_user),
):
    user_id = get_user_id(user)

    query = (
        supabase.table("customers")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
    )

    response = query.execute()
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

    return {
        "customers": customers,
        "count": len(customers),
    }


@router.post("")
def create_customer(
    payload: CustomerCreate,
    user=Depends(get_logged_in_user),
):
    user_id = get_user_id(user)

    instagram_username = payload.instagram_username.strip()

    if not instagram_username:
        raise HTTPException(
            status_code=400,
            detail="Instagram username is required",
        )

    existing_response = (
        supabase.table("customers")
        .select("id")
        .eq("user_id", user_id)
        .eq("instagram_username", instagram_username)
        .execute()
    )

    if existing_response.data:
        raise HTTPException(
            status_code=400,
            detail="Customer with this Instagram username already exists",
        )

    customer_data = {
        "user_id": user_id,
        "instagram_username": instagram_username,
        "display_name": payload.display_name,
        "email": payload.email,
        "phone": payload.phone,
    }

    response = supabase.table("customers").insert(customer_data).execute()

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
    user_id = get_user_id(user)

    existing_response = (
        supabase.table("customers")
        .select("*")
        .eq("id", customer_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not existing_response.data:
        raise HTTPException(
            status_code=404,
            detail="Customer not found",
        )

    update_data = {}

    if payload.instagram_username is not None:
        username = payload.instagram_username.strip()

        if not username:
            raise HTTPException(
                status_code=400,
                detail="Instagram username cannot be empty",
            )

        duplicate_response = (
            supabase.table("customers")
            .select("id")
            .eq("user_id", user_id)
            .eq("instagram_username", username)
            .neq("id", customer_id)
            .execute()
        )

        if duplicate_response.data:
            raise HTTPException(
                status_code=400,
                detail="Another customer already uses this Instagram username",
            )

        update_data["instagram_username"] = username

    if payload.display_name is not None:
        update_data["display_name"] = payload.display_name

    if payload.email is not None:
        update_data["email"] = payload.email

    if payload.phone is not None:
        update_data["phone"] = payload.phone

    if payload.is_vip is not None:
        update_data["is_vip"] = payload.is_vip

    if not update_data:
        raise HTTPException(
            status_code=400,
            detail="No fields to update",
        )

    response = (
        supabase.table("customers")
        .update(update_data)
        .eq("id", customer_id)
        .eq("user_id", user_id)
        .execute()
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
    user_id = get_user_id(user)

    existing_response = (
        supabase.table("customers")
        .select("*")
        .eq("id", customer_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not existing_response.data:
        raise HTTPException(
            status_code=404,
            detail="Customer not found",
        )

    order_response = (
        supabase.table("orders")
        .select("id")
        .eq("customer_id", customer_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )

    if order_response.data:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete customer with existing orders",
        )

    (
        supabase.table("customers")
        .delete()
        .eq("id", customer_id)
        .eq("user_id", user_id)
        .execute()
    )

    return {
        "message": "Customer deleted successfully",
    }