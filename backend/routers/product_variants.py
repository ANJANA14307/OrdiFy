from fastapi import APIRouter, Depends, HTTPException

from core.auth import get_logged_in_user
from core.supabase import supabase
from schemas.product_variant import ProductVariantCreate, ProductVariantUpdate


router = APIRouter(
    prefix="/products/{product_id}/variants",
    tags=["Product Variants"],
)


def _business_id(user) -> str:
    user_id = getattr(user, "id", None)
    if user_id:
        return str(user_id)
    if isinstance(user, dict) and user.get("id"):
        return str(user["id"])
    raise HTTPException(status_code=401, detail="Invalid user")


def _owned_product(product_id: str, business_id: str) -> None:
    response = (
        supabase.table("products")
        .select("id")
        .eq("id", product_id)
        .eq("user_id", business_id)
        .eq("is_active", True)
        .limit(1)
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="Product not found")


def _variant_code_exists(
    business_id: str,
    code: str,
    *,
    exclude_variant_id: str | None = None,
) -> bool:
    query = (
        supabase.table("product_variants")
        .select("id")
        .eq("business_id", business_id)
        .eq("code", code)
    )
    if exclude_variant_id:
        query = query.neq("id", exclude_variant_id)
    return bool(query.limit(1).execute().data)


def _raise_variant_error(error: Exception) -> None:
    error_text = str(error).lower()
    if "unique" in error_text or "duplicate key" in error_text:
        raise HTTPException(
            status_code=409,
            detail="A variant with this code already exists for this business",
        ) from error
    raise HTTPException(
        status_code=500,
        detail=f"Product variant operation failed: {error}",
    ) from error


@router.get("")
def list_product_variants(
    product_id: str,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    _owned_product(product_id, business_id)

    try:
        response = (
            supabase.table("product_variants")
            .select("*")
            .eq("business_id", business_id)
            .eq("product_id", product_id)
            .order("created_at")
            .execute()
        )
    except Exception as error:
        _raise_variant_error(error)

    return {"variants": response.data or []}


@router.post("")
def create_product_variant(
    product_id: str,
    payload: ProductVariantCreate,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    _owned_product(product_id, business_id)

    try:
        if _variant_code_exists(business_id, payload.code):
            raise HTTPException(
                status_code=409,
                detail="A variant with this code already exists for this business",
            )

        response = (
            supabase.table("product_variants")
            .insert(
                {
                    **payload.model_dump(),
                    "product_id": product_id,
                    "business_id": business_id,
                }
            )
            .select()
            .execute()
        )
    except HTTPException:
        raise
    except Exception as error:
        _raise_variant_error(error)

    if not response.data:
        raise HTTPException(status_code=500, detail="Variant could not be created")
    return {"variant": response.data[0]}


@router.patch("/{variant_id}")
def update_product_variant(
    product_id: str,
    variant_id: str,
    payload: ProductVariantUpdate,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    _owned_product(product_id, business_id)
    update_data = payload.model_dump(exclude_none=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields provided for update")

    try:
        if "code" in update_data and _variant_code_exists(
            business_id,
            update_data["code"],
            exclude_variant_id=variant_id,
        ):
            raise HTTPException(
                status_code=409,
                detail="A variant with this code already exists for this business",
            )

        response = (
            supabase.table("product_variants")
            .update(update_data)
            .eq("id", variant_id)
            .eq("business_id", business_id)
            .eq("product_id", product_id)
            .select()
            .execute()
        )
    except HTTPException:
        raise
    except Exception as error:
        _raise_variant_error(error)

    if not response.data:
        raise HTTPException(status_code=404, detail="Variant not found")
    return {"variant": response.data[0]}
