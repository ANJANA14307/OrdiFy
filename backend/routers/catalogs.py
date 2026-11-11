import re
import secrets

from fastapi import APIRouter, Depends, HTTPException

from core.auth import get_logged_in_user
from core.config import settings
from core.supabase import supabase
from schemas.catalog import CatalogSettingsUpdate


router = APIRouter(prefix="/catalogs", tags=["Catalogs"])


def _business_id(user) -> str:
    user_id = getattr(user, "id", None)
    if user_id:
        return str(user_id)
    if isinstance(user, dict) and user.get("id"):
        return str(user["id"])
    raise HTTPException(status_code=401, detail="Invalid user")


def _catalog_url(slug: str) -> str:
    base_url = (settings.PUBLIC_CATALOG_BASE_URL or "").strip().rstrip("/")
    if not base_url:
        raise HTTPException(
            status_code=503,
            detail="Public catalog base URL is not configured",
        )
    return f"{base_url}/#/catalog/{slug}"


def _slug_for_business(business_name: str | None) -> str:
    name = re.sub(r"[^a-z0-9]+", "-", (business_name or "shop").lower()).strip("-")
    return f"{name[:36] or 'shop'}-{secrets.token_hex(8)}"


def _get_or_create_catalog(business_id: str) -> dict:
    response = (
        supabase.table("catalog_settings")
        .select("*")
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    if response.data:
        return response.data[0]

    profile_response = (
        supabase.table("profiles")
        .select("business_name")
        .eq("id", business_id)
        .limit(1)
        .execute()
    )
    business_name = (
        profile_response.data[0].get("business_name")
        if profile_response.data
        else None
    )
    created = (
        supabase.table("catalog_settings")
        .insert(
            {
                "business_id": business_id,
                "slug": _slug_for_business(business_name),
                "is_public": False,
                "selected_product_ids": [],
                "selected_listing_ids": [],
            }
        )
        .select("*")
        .execute()
    )
    if not created.data:
        raise HTTPException(status_code=500, detail="Catalog settings could not be created")
    return created.data[0]


def _owned_active_products(business_id: str, selected_ids: list[str] | None = None):
    query = (
        supabase.table("products")
        .select("*")
        .eq("user_id", business_id)
        .eq("is_active", True)
        .order("name")
    )
    if selected_ids is not None:
        if not selected_ids:
            return []
        query = query.in_("id", selected_ids)
    response = query.execute()
    allowed_fields = {
        "id",
        "name",
        "description",
        "category",
        "price",
        "stock_count",
        "image_url",
        "is_active",
    }
    return [
        {key: value for key, value in product.items() if key in allowed_fields}
        for product in response.data or []
    ]


def _attach_codes(
    products: list[dict],
    business_id: str,
    catalog_slug: str,
) -> list[dict]:
    product_ids = [str(product["id"]) for product in products]
    if not product_ids:
        return products
    try:
        variants_response = (
            supabase.table("product_variants")
            .select("product_id,code,attributes")
            .eq("business_id", business_id)
            .eq("is_active", True)
            .in_("product_id", product_ids)
            .order("code")
            .execute()
        )
        variants = variants_response.data or []
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Product codes could not be loaded: {error}",
        ) from error

    by_product: dict[str, list[dict]] = {}
    for variant in variants:
        by_product.setdefault(str(variant["product_id"]), []).append(
            {
                "code": variant.get("code"),
                "attributes": variant.get("attributes") or {},
            }
        )
    for product in products:
        product["variants"] = by_product.get(str(product["id"]), [])
        product["code"] = (
            product["variants"][0]["code"] if product["variants"] else None
        )
        product["product_url"] = (
            f"{_catalog_url(catalog_slug)}?product={product['id']}"
        )
    return products


def _business_name(business_id: str) -> str:
    response = (
        supabase.table("profiles")
        .select("business_name")
        .eq("id", business_id)
        .limit(1)
        .execute()
    )
    if not response.data:
        return "Store"
    return response.data[0].get("business_name") or "Store"


@router.get("/me")
def get_my_catalog(user=Depends(get_logged_in_user)):
    business_id = _business_id(user)
    catalog = _get_or_create_catalog(business_id)
    products = _owned_active_products(business_id)
    products = _attach_codes(products, business_id, catalog["slug"])
    listings = _owned_active_listings(business_id)
    for listing in listings:
        listing["product_url"] = (
            f"{_catalog_url(catalog['slug'])}?product={listing['id']}"
        )
    return {
        "catalog": {
            "slug": catalog["slug"],
            "is_public": catalog["is_public"],
            "selected_product_ids": catalog.get("selected_product_ids") or [],
            "selected_listing_ids": catalog.get("selected_listing_ids") or [],
            "url": _catalog_url(catalog["slug"]),
        },
        "business": {"name": _business_name(business_id)},
        "products": products,
        "listings": listings,
    }


@router.put("/me")
def update_my_catalog(
    payload: CatalogSettingsUpdate,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    catalog = _get_or_create_catalog(business_id)
    available_products = _owned_active_products(business_id)
    available_ids = {str(product["id"]) for product in available_products}
    selected_ids = list(dict.fromkeys(payload.selected_product_ids))
    selected_listing_ids = (
        list(dict.fromkeys(payload.selected_listing_ids))
        if payload.selected_listing_ids is not None
        else list(catalog.get("selected_listing_ids") or [])
    )
    available_listings = _owned_active_listings(business_id)
    available_listing_ids = {
        str(listing["id"]) for listing in available_listings
    }
    if payload.is_public and not selected_ids and not selected_listing_ids:
        raise HTTPException(
            status_code=400,
            detail="Select at least one product before publishing the catalog",
        )
    invalid_ids = [product_id for product_id in selected_ids if product_id not in available_ids]
    if invalid_ids:
        raise HTTPException(
            status_code=400,
            detail="Selected products must be active products owned by this business",
        )
    if any(item not in available_listing_ids for item in selected_listing_ids):
        raise HTTPException(
            status_code=400,
            detail="Selected listings must be active listings owned by this business",
        )

    try:
        response = (
            supabase.table("catalog_settings")
            .update(
                {
                    "is_public": payload.is_public,
                    "selected_product_ids": selected_ids,
                    "selected_listing_ids": selected_listing_ids,
                }
            )
            .eq("business_id", business_id)
            .select("*")
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Catalog settings could not be saved: {error}",
        ) from error

    if not response.data:
        raise HTTPException(status_code=500, detail="Catalog settings could not be saved")
    saved = response.data[0]
    return {
        "catalog": {
            "slug": saved["slug"],
            "is_public": saved["is_public"],
            "selected_product_ids": saved.get("selected_product_ids") or [],
            "selected_listing_ids": saved.get("selected_listing_ids") or [],
            "url": _catalog_url(saved["slug"]),
        }
    }


@router.get("/public/{slug}")
def get_public_catalog(slug: str):
    response = (
        supabase.table("catalog_settings")
        .select("business_id,slug,is_public,selected_product_ids,selected_listing_ids")
        .eq("slug", slug)
        .eq("is_public", True)
        .limit(1)
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="Catalog is private or unavailable")

    catalog = response.data[0]
    business_id = str(catalog["business_id"])
    selected_ids = [str(item) for item in catalog.get("selected_product_ids") or []]
    products = _owned_active_products(business_id, selected_ids)
    products = _attach_codes(products, business_id, catalog["slug"])
    selected_listing_ids = [
        str(item) for item in catalog.get("selected_listing_ids") or []
    ]
    listings = _owned_active_listings(business_id, selected_listing_ids)
    products.extend(
        _listing_as_catalog_product(listing, catalog["slug"])
        for listing in listings
    )
    return {
        "catalog": {
            "slug": catalog["slug"],
            "is_public": True,
            "url": _catalog_url(catalog["slug"]),
        },
        "business": {"name": _business_name(business_id)},
        "products": products,
    }


def _owned_active_listings(
    business_id: str,
    selected_ids: list[str] | None = None,
) -> list[dict]:
    query = (
        supabase.table("business_listings")
        .select("*")
        .eq("business_id", business_id)
        .eq("is_active", True)
        .order("created_at", desc=True)
    )
    if selected_ids is not None:
        if not selected_ids:
            return []
        query = query.in_("id", selected_ids)
    listings = query.execute().data or []
    if not listings:
        return []
    product_ids = list(
        dict.fromkeys(str(listing["catalog_product_id"]) for listing in listings)
    )
    listing_ids = [str(listing["id"]) for listing in listings]
    products_response = (
        supabase.table("catalog_products")
        .select("id,name,brand,category,description,images")
        .eq("status", "approved")
        .in_("id", product_ids)
        .execute()
    )
    variants_response = (
        supabase.table("business_listing_variants")
        .select("listing_id,code,attributes,price,stock,is_active")
        .eq("business_id", business_id)
        .eq("is_active", True)
        .in_("listing_id", listing_ids)
        .order("code")
        .execute()
    )
    products = {
        str(product["id"]): product for product in products_response.data or []
    }
    variants_by_listing: dict[str, list[dict]] = {}
    for variant in variants_response.data or []:
        variants_by_listing.setdefault(str(variant["listing_id"]), []).append(
            {
                "code": variant.get("code"),
                "attributes": variant.get("attributes") or {},
                "price": variant.get("price"),
                "stock": variant.get("stock"),
            }
        )
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
    return result


def _listing_as_catalog_product(listing: dict, slug: str) -> dict:
    product = listing["catalog_product"]
    variants = listing.get("variants") or []
    return {
        "id": listing["id"],
        "listing_id": listing["id"],
        "catalog_product_id": product["id"],
        "name": product["name"],
        "brand": product.get("brand"),
        "category": product.get("category"),
        "description": product.get("description"),
        "image_url": (product.get("images") or [None])[0],
        "images": product.get("images") or [],
        "price": listing["price"],
        "stock_count": listing["stock"],
        "is_active": listing["is_active"],
        "variants": variants,
        "code": variants[0]["code"] if variants else None,
        "product_url": f"{_catalog_url(slug)}?product={listing['id']}",
    }
