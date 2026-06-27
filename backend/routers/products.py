from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from core.supabase import supabase
from core.auth import get_logged_in_user, ensure_profile_exists
from schemas.product import ProductCreate, ProductUpdate
from services.cloudinary_service import upload_product_image

router = APIRouter(
    prefix="/products",
    tags=["Products"]
)

@router.post("/upload-image")
async def upload_image(
    file: UploadFile = File(...),
    user=Depends(get_logged_in_user)
):
    result = await upload_product_image(file, user.id)

    return {
        "message": "Image uploaded successfully",
        "image_url": result["secure_url"],
        "public_id": result["public_id"]
    }
@router.post("")
async def create_product(
    product: ProductCreate,
    user=Depends(get_logged_in_user)
):
    ensure_profile_exists(user)

    product_data = product.model_dump()
    product_data["user_id"] = user.id
    product_data["is_active"] = True

    try:
        response = supabase.table("products").insert(product_data).select().execute()
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Product could not be created: {str(exc)}"
        )

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Product could not be created"
        )

    return {
        "message": "Product created successfully",
        "product": response.data[0]
    }


@router.get("")
async def list_products(
    user=Depends(get_logged_in_user),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, ge=1, le=50)
):
    start = (page - 1) * limit
    end = start + limit - 1

    try:
        response = supabase.table("products").select("*").eq(
            "user_id", user.id
        ).eq(
            "is_active", True
        ).order(
            "created_at", desc=True
        ).range(
            start, end
        ).execute()
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Products could not be fetched: {str(exc)}"
        )

    return {
        "page": page,
        "limit": limit,
        "products": response.data
    }


@router.get("/{product_id}")
async def get_product(
    product_id: str,
    user=Depends(get_logged_in_user)
):
    try:
        response = supabase.table("products").select("*").eq(
            "id", product_id
        ).eq(
            "user_id", user.id
        ).eq(
            "is_active", True
        ).execute()
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Product could not be fetched: {str(exc)}"
        )

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail="Product not found"
        )

    return {
        "product": response.data[0]
    }


@router.patch("/{product_id}")
async def update_product(
    product_id: str,
    product: ProductUpdate,
    user=Depends(get_logged_in_user)
):
    update_data = product.model_dump(exclude_none=True)

    if not update_data:
        raise HTTPException(
            status_code=400,
            detail="No fields provided for update"
        )

    try:
        response = supabase.table("products").update(update_data).eq(
            "id", product_id
        ).eq(
            "user_id", user.id
        ).eq(
            "is_active", True
        ).select().execute()
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Product could not be updated: {str(exc)}"
        )

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail="Product not found or not updated"
        )

    return {
        "message": "Product updated successfully",
        "product": response.data[0]
    }


@router.delete("/{product_id}")
async def delete_product(
    product_id: str,
    user=Depends(get_logged_in_user)
):
    try:
        response = supabase.table("products").update({
            "is_active": False
        }).eq(
            "id", product_id
        ).eq(
            "user_id", user.id
        ).eq(
            "is_active", True
        ).select().execute()
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Product could not be deleted: {str(exc)}"
        )

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail="Product not found or already deleted"
        )

    return {
        "message": "Product deleted successfully"
    }