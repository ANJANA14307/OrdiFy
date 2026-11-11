from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query

from core.auth import get_logged_in_user
from core.supabase import supabase
from schemas.shared_catalog import (
    BusinessListingCreate,
    BusinessListingUpdate,
    CatalogProductReview,
    CatalogProductSuggestion,
    ProductCatalogMappingCreate,
)


router = APIRouter(prefix="/shared-catalog", tags=["Shared Catalog"])


def _business_id(user: Any) -> str:
    user_id = getattr(user, "id", None)
    if user_id:
        return str(user_id)
    if isinstance(user, dict) and user.get("id"):
        return str(user["id"])
    raise HTTPException(status_code=401, detail="Invalid user")


def _require_catalog_admin(user: Any) -> None:
    metadata = getattr(user, "app_metadata", None)
    if not isinstance(metadata, dict) and isinstance(user, dict):
        metadata = user.get("app_metadata")
    metadata = metadata if isinstance(metadata, dict) else {}
    if metadata.get("catalog_admin") is not True and metadata.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Catalog reviewer access required")


def _approved_product(product_id: str) -> dict:
    response = (
        supabase.table("catalog_products")
        .select("id,name,brand,category,description,images,status")
        .eq("id", product_id)
        .eq("status", "approved")
        .limit(1)
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="Catalog product not found")
    return response.data[0]


def _owned_listing(listing_id: str, business_id: str) -> dict:
    response = (
        supabase.table("business_listings")
        .select("*")
        .eq("id", listing_id)
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="Business listing not found")
    return response.data[0]


@router.get("/products")
def search_catalog_products(
    q: str | None = Query(default=None, max_length=120),
    brand: str | None = Query(default=None, max_length=120),
    category: str | None = Query(default=None, max_length=100),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=30, ge=1, le=100),
    user=Depends(get_logged_in_user),
):
    query = (
        supabase.table("catalog_products")
        .select("id,name,brand,category,description,images")
        .eq("status", "approved")
        .order("name")
    )
    if q and q.strip():
        query = query.ilike("name", f"%{q.strip()}%")
    if brand and brand.strip():
        query = query.ilike("brand", f"%{brand.strip()}%")
    if category and category.strip():
        query = query.ilike("category", f"%{category.strip()}%")
    start = (page - 1) * limit
    try:
        response = query.range(start, start + limit - 1).execute()
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Shared catalog could not be searched: {error}",
        ) from error
    return {"products": response.data or [], "page": page, "limit": limit}


@router.get("/products/{catalog_product_id}")
def get_catalog_product(
    catalog_product_id: str,
    user=Depends(get_logged_in_user),
):
    return {"product": _approved_product(catalog_product_id)}


@router.post("/suggestions", status_code=201)
def suggest_catalog_product(
    payload: CatalogProductSuggestion,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    data = {
        **payload.model_dump(),
        "status": "pending_review",
        "submitted_by": business_id,
    }
    try:
        response = supabase.table("catalog_products").insert(data).select(
            "id,name,brand,category,description,images,status,created_at"
        ).execute()
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Catalog product suggestion could not be submitted: {error}",
        ) from error
    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Catalog product suggestion could not be submitted",
        )
    return {"product": response.data[0]}


@router.get("/review/suggestions")
def list_catalog_product_suggestions(
    status: str = Query(default="pending_review"),
    user=Depends(get_logged_in_user),
):
    _require_catalog_admin(user)
    if status not in {"pending_review", "approved", "rejected"}:
        raise HTTPException(status_code=400, detail="Invalid review status")
    response = (
        supabase.table("catalog_products")
        .select("id,name,brand,category,description,images,status,review_notes,created_at")
        .eq("status", status)
        .order("created_at")
        .execute()
    )
    return {"suggestions": response.data or []}


@router.patch("/review/suggestions/{catalog_product_id}")
def review_catalog_product_suggestion(
    catalog_product_id: str,
    payload: CatalogProductReview,
    user=Depends(get_logged_in_user),
):
    _require_catalog_admin(user)
    response = (
        supabase.table("catalog_products")
        .update(
            {
                "status": payload.status,
                "review_notes": payload.review_notes,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            }
        )
        .eq("id", catalog_product_id)
        .eq("status", "pending_review")
        .select("id,name,brand,category,description,images,status,review_notes")
        .execute()
    )
    if not response.data:
        raise HTTPException(
            status_code=409,
            detail="Suggestion is not pending review or does not exist",
        )
    return {"product": response.data[0]}


@router.post("/listings", status_code=201)
def create_business_listing(
    payload: BusinessListingCreate,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    _approved_product(str(payload.catalog_product_id))
    codes = [variant.code for variant in payload.variants]
    if len(codes) != len(set(codes)):
        raise HTTPException(
            status_code=422,
            detail="Variant codes must be unique within this listing",
        )
    try:
        response = supabase.rpc(
            "create_business_listing",
            {
                "p_business_id": business_id,
                "p_catalog_product_id": str(payload.catalog_product_id),
                "p_price": payload.price,
                "p_stock": payload.stock,
                "p_variants": [variant.model_dump() for variant in payload.variants],
                "p_delivery_override": payload.delivery_override,
                "p_return_policy_override": payload.return_policy_override,
            },
        ).execute()
    except Exception as error:
        detail = str(error)
        message = detail.lower()
        if "business_listings_one_product_per_business" in message:
            raise HTTPException(
                status_code=409,
                detail="You already have a listing for this catalog product",
            ) from error
        if "business_listing_variant_business_code_unique" in message:
            raise HTTPException(
                status_code=409,
                detail="A variant with this code already exists for your business",
            ) from error
        if "variant code" in message or "catalog product" in message:
            raise HTTPException(status_code=422, detail=detail) from error
        raise HTTPException(
            status_code=500,
            detail=f"Business listing could not be created: {detail}",
        ) from error
    data = response.data
    if isinstance(data, list):
        data = data[0] if data else None
    if not data:
        raise HTTPException(
            status_code=500,
            detail="Business listing could not be created",
        )
    data["catalog_product"] = _approved_product(str(payload.catalog_product_id))
    return {"listing": data}


@router.get("/listings")
def list_my_business_listings(
    include_inactive: bool = False,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    query = (
        supabase.table("business_listings")
        .select("*")
        .eq("business_id", business_id)
        .order("created_at", desc=True)
    )
    if not include_inactive:
        query = query.eq("is_active", True)
    try:
        listings = query.execute().data or []
        if not listings:
            return {"listings": []}
        listing_ids = [str(listing["id"]) for listing in listings]
        product_ids = list(
            dict.fromkeys(str(listing["catalog_product_id"]) for listing in listings)
        )
        products_response = (
            supabase.table("catalog_products")
            .select("id,name,brand,category,description,images")
            .eq("status", "approved")
            .in_("id", product_ids)
            .execute()
        )
        variants_response = (
            supabase.table("business_listing_variants")
            .select("*")
            .eq("business_id", business_id)
            .in_("listing_id", listing_ids)
            .order("code")
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Business listings could not be loaded: {error}",
        ) from error

    products = {
        str(product["id"]): product for product in products_response.data or []
    }
    variants_by_listing: dict[str, list[dict]] = {}
    for variant in variants_response.data or []:
        variants_by_listing.setdefault(str(variant["listing_id"]), []).append(variant)
    result = []
    for listing in listings:
        product = products.get(str(listing["catalog_product_id"]))
        if product is None:
            continue
        result.append(
            {
                **listing,
                "catalog_product": product,
                "variants": variants_by_listing.get(str(listing["id"]), []),
            }
        )
    return {"listings": result}


@router.patch("/listings/{listing_id}")
def update_business_listing(
    listing_id: str,
    payload: BusinessListingUpdate,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    values = payload.model_dump(exclude_unset=True)
    if not values:
        raise HTTPException(status_code=400, detail="No listing fields provided")
    values["updated_at"] = datetime.now(timezone.utc).isoformat()
    try:
        response = (
            supabase.table("business_listings")
            .update(values)
            .eq("id", listing_id)
            .eq("business_id", business_id)
            .select("*")
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Business listing could not be updated: {error}",
        ) from error
    if not response.data:
        raise HTTPException(status_code=404, detail="Business listing not found")
    listing = response.data[0]
    listing["catalog_product"] = _approved_product(
        str(listing["catalog_product_id"])
    )
    return {"listing": listing}


@router.get("/mappings/{product_id}")
def get_product_catalog_mapping(
    product_id: str,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    owned_product = (
        supabase.table("products")
        .select("id")
        .eq("id", product_id)
        .eq("user_id", business_id)
        .limit(1)
        .execute()
    )
    if not owned_product.data:
        raise HTTPException(status_code=404, detail="Product not found")
    response = (
        supabase.table("product_catalog_mappings")
        .select("product_id,business_id,catalog_product_id,created_at")
        .eq("product_id", product_id)
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    mapping = response.data[0] if response.data else None
    if mapping:
        mapping["catalog_product"] = _approved_product(
            str(mapping["catalog_product_id"])
        )
    return {"mapping": mapping}


@router.put("/mappings/{product_id}")
def map_owned_product_to_catalog(
    product_id: str,
    payload: ProductCatalogMappingCreate,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    owned_product = (
        supabase.table("products")
        .select("id")
        .eq("id", product_id)
        .eq("user_id", business_id)
        .limit(1)
        .execute()
    )
    if not owned_product.data:
        raise HTTPException(status_code=404, detail="Product not found")
    _approved_product(str(payload.catalog_product_id))
    try:
        response = (
            supabase.table("product_catalog_mappings")
            .upsert(
                {
                    "product_id": product_id,
                    "business_id": business_id,
                    "catalog_product_id": str(payload.catalog_product_id),
                },
                on_conflict="product_id",
            )
            .select("product_id,business_id,catalog_product_id,created_at")
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Product catalog mapping could not be saved: {error}",
        ) from error
    if not response.data:
        raise HTTPException(status_code=500, detail="Product catalog mapping could not be saved")
    mapping = response.data[0]
    mapping["catalog_product"] = _approved_product(
        str(mapping["catalog_product_id"])
    )
    return {"mapping": mapping}


@router.delete("/mappings/{product_id}")
def delete_product_catalog_mapping(
    product_id: str,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    response = (
        supabase.table("product_catalog_mappings")
        .delete()
        .eq("product_id", product_id)
        .eq("business_id", business_id)
        .execute()
    )
    return {"deleted": bool(response.data)}
