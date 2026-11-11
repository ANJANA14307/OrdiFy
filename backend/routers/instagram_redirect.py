import re
import hashlib
import hmac
from datetime import datetime, timezone
from typing import Any
from urllib.parse import quote

import httpx
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from fastapi.responses import PlainTextResponse, RedirectResponse
from pydantic import ValidationError

from core.auth import get_logged_in_user
from core.config import settings
from core.supabase import supabase
from schemas.instagram_redirect import (
    InstagramConfigUpdate,
    InstagramRedirectDestination,
)


router = APIRouter(prefix="/instagram-tools", tags=["Instagram Redirect Tools"])
redirect_router = APIRouter(prefix="/instagram-redirect", tags=["Instagram Redirects"])
webhook_router = APIRouter(prefix="/webhooks/instagram", tags=["Instagram Webhook"])
GRAPH_API_BASE = "https://graph.instagram.com/v22.0"
DEFAULT_KEYWORDS = ["price", "order"]
DEFAULT_REPLY = (
    "Thanks for reaching out! Browse the catalog: {catalog_link}\n"
    "To order, message us on WhatsApp: {whatsapp_link}"
)


def _business_id(user: Any) -> str:
    user_id = getattr(user, "id", None)
    if user_id:
        return str(user_id)
    if isinstance(user, dict) and user.get("id"):
        return str(user["id"])
    raise HTTPException(status_code=401, detail="Invalid user")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _get_catalog(business_id: str) -> dict | None:
    response = (
        supabase.table("catalog_settings")
        .select("*")
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None


def _get_config(business_id: str) -> dict | None:
    response = (
        supabase.table("instagram_redirect_settings")
        .select("*")
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None


def _profile_status(business_id: str) -> dict:
    if not settings.INSTAGRAM_ACCESS_TOKEN:
        return {
            "status": "permission_needed",
            "username": None,
            "connected_at": None,
        }
    response = (
        supabase.table("profiles")
        .select("instagram_user_id,instagram_username,instagram_connected_at")
        .eq("id", business_id)
        .limit(1)
        .execute()
    )
    profile = response.data[0] if response.data else {}
    if profile.get("instagram_user_id") and profile.get("instagram_username"):
        return {
            "status": "connected",
            "username": profile.get("instagram_username"),
            "connected_at": profile.get("instagram_connected_at"),
        }
    return {"status": "not_connected", "username": None, "connected_at": None}


def _tracking_url(
    catalog_slug: str,
    destination: str,
    tag: str,
    product_id: str | None = None,
) -> str:
    api_base = (settings.PUBLIC_API_BASE_URL or "").strip().rstrip("/")
    if not api_base:
        raise HTTPException(
            status_code=503,
            detail="Public API base URL is not configured for Instagram tracking links",
        )
    url = f"{api_base}/instagram-redirect/{catalog_slug}/{destination}?tag={quote(tag)}"
    if product_id:
        url += f"&product_id={quote(product_id)}"
    return url


def _tracked_links(business_id: str, tag: str = "bio") -> dict:
    catalog = _get_catalog(business_id)
    links: dict[str, Any] = {"catalog": None, "whatsapp": None, "products": {}}
    if (
        not catalog
        or not catalog.get("is_public")
        or not (settings.PUBLIC_API_BASE_URL or "").strip()
    ):
        return links
    links["catalog"] = _tracking_url(catalog["slug"], "catalog", tag)

    wa_settings = (
        supabase.table("whatsapp_order_settings")
        .select("phone_number")
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    if wa_settings.data and wa_settings.data[0].get("phone_number"):
        links["whatsapp"] = _tracking_url(catalog["slug"], "whatsapp", tag)

    selected_ids = catalog.get("selected_product_ids") or []
    if selected_ids:
        products = (
            supabase.table("products")
            .select("id,name,price,image_url,stock_count,is_active")
            .eq("user_id", business_id)
            .eq("is_active", True)
            .in_("id", selected_ids)
            .order("name")
            .execute()
        )
        variants_response = (
            supabase.table("product_variants")
            .select("product_id,code,attributes")
            .eq("business_id", business_id)
            .eq("is_active", True)
            .in_("product_id", selected_ids)
            .order("code")
            .execute()
        )
        codes_by_product: dict[str, list[str]] = {}
        for variant in variants_response.data or []:
            codes_by_product.setdefault(str(variant["product_id"]), []).append(
                str(variant["code"])
            )
        for product in products.data or []:
            product_id = str(product["id"])
            links["products"][product_id] = {
                **product,
                "code": (codes_by_product.get(product_id) or [None])[0],
                "codes": codes_by_product.get(product_id) or [],
                "url": _tracking_url(catalog["slug"], "product", tag, product_id),
            }
    return links


def _stats(business_id: str) -> dict:
    click_response = (
        supabase.table("instagram_redirect_clicks")
        .select("id", count="exact", head=True)
        .eq("business_id", business_id)
        .execute()
    )
    order_response = (
        supabase.table("orders")
        .select("id", count="exact", head=True)
        .eq("user_id", business_id)
        .eq("source", "dm")
        .execute()
    )
    return {
        "link_clicks": int(click_response.count or 0),
        "orders": int(order_response.count or 0),
    }


@router.get("/me")
def get_instagram_tools(user=Depends(get_logged_in_user)):
    business_id = _business_id(user)
    catalog = _get_catalog(business_id)
    config = _get_config(business_id) or {}
    connection = _profile_status(business_id)
    return {
        "config": {
            "is_enabled": bool(config.get("is_enabled")),
            "trigger_keywords": config.get("trigger_keywords") or DEFAULT_KEYWORDS,
            "reply_text": config.get("reply_text") or DEFAULT_REPLY,
        },
        "connection": connection,
        "catalog": {
            "is_public": bool(catalog and catalog.get("is_public")),
        },
        "links": _tracked_links(business_id),
        "tracking_configured": bool(
            (settings.PUBLIC_API_BASE_URL or "").strip()
        ),
        "stats": _stats(business_id),
        "auto_reply_supported": bool(
            settings.INSTAGRAM_ACCESS_TOKEN
            and settings.META_APP_SECRET
            and settings.VERIFY_TOKEN
        ),
    }


@router.put("/me")
def save_instagram_tools(
    payload: InstagramConfigUpdate,
    user=Depends(get_logged_in_user),
):
    business_id = _business_id(user)
    if payload.is_enabled:
        if not payload.trigger_keywords:
            raise HTTPException(
                status_code=400,
                detail="Add at least one trigger keyword before enabling automatic replies",
            )
        connection = _profile_status(business_id)
        if connection["status"] != "connected":
            raise HTTPException(
                status_code=409,
                detail="Connect Instagram before enabling automatic replies",
            )
        if not (
            settings.INSTAGRAM_ACCESS_TOKEN
            and settings.META_APP_SECRET
            and settings.VERIFY_TOKEN
        ):
            raise HTTPException(
                status_code=503,
                detail=(
                    "Configure Instagram API access, META_APP_SECRET, and "
                    "VERIFY_TOKEN before enabling automatic replies"
                ),
            )
        links = _tracked_links(business_id, "auto_reply")
        if not links["catalog"] or not links["whatsapp"]:
            raise HTTPException(
                status_code=400,
                detail="Publish your catalog and configure a WhatsApp number before enabling auto-replies",
            )
    try:
        response = (
            supabase.table("instagram_redirect_settings")
            .upsert(
                {
                    "business_id": business_id,
                    **payload.model_dump(),
                    "updated_at": _now(),
                },
                on_conflict="business_id",
            )
            .select("*")
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Instagram redirect settings could not be saved: {error}",
        ) from error
    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Instagram redirect settings could not be saved",
        )
    catalog = _get_catalog(business_id)
    return {
        "config": {
            "is_enabled": response.data[0].get("is_enabled", False),
            "trigger_keywords": response.data[0].get("trigger_keywords") or [],
            "reply_text": response.data[0].get("reply_text") or DEFAULT_REPLY,
        },
        "connection": _profile_status(business_id),
        "catalog": {
            "is_public": bool(catalog and catalog.get("is_public")),
        },
        "links": _tracked_links(business_id),
        "tracking_configured": bool(
            (settings.PUBLIC_API_BASE_URL or "").strip()
        ),
        "stats": _stats(business_id),
        "auto_reply_supported": bool(
            settings.INSTAGRAM_ACCESS_TOKEN
            and settings.META_APP_SECRET
            and settings.VERIFY_TOKEN
        ),
    }


@router.post("/connect")
async def connect_instagram_tools(user=Depends(get_logged_in_user)):
    business_id = _business_id(user)
    if not settings.INSTAGRAM_ACCESS_TOKEN:
        raise HTTPException(
            status_code=503,
            detail="Instagram API access is not configured on the backend",
        )
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.get(
                "https://graph.instagram.com/me",
                params={
                    "fields": "user_id,username",
                    "access_token": settings.INSTAGRAM_ACCESS_TOKEN,
                },
            )
    except httpx.RequestError as error:
        raise HTTPException(
            status_code=502,
            detail=f"Instagram could not be reached: {error}",
        ) from error
    if response.is_error:
        raise HTTPException(
            status_code=403,
            detail="Instagram connection needs valid API access and permissions",
        )
    instagram_profile = response.json()
    instagram_user_id = str(instagram_profile.get("user_id") or "")
    if not instagram_user_id or not instagram_profile.get("username"):
        raise HTTPException(
            status_code=502,
            detail="Instagram did not return a user ID and username",
        )
    existing_connection = (
        supabase.table("profiles")
        .select("id")
        .eq("instagram_user_id", instagram_user_id)
        .neq("id", business_id)
        .limit(1)
        .execute()
    )
    if existing_connection.data:
        raise HTTPException(
            status_code=409,
            detail="This Instagram account is already connected to another business",
        )
    update = (
        supabase.table("profiles")
        .update(
            {
                "instagram_user_id": instagram_user_id,
                "instagram_username": instagram_profile.get("username"),
                "instagram_connected_at": _now(),
            }
        )
        .eq("id", business_id)
        .select("id")
        .execute()
    )
    if not update.data:
        raise HTTPException(status_code=404, detail="Business profile was not found")
    return {"connection": _profile_status(business_id)}


@redirect_router.get("/{catalog_slug}/{destination}")
def follow_instagram_redirect(
    catalog_slug: str,
    destination: str,
    tag: str = Query(default="bio", max_length=40),
    product_id: str | None = Query(default=None),
):
    try:
        requested = InstagramRedirectDestination(
            destination=destination,
            tag=tag,
            product_id=product_id,
        )
    except ValidationError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    catalog_response = (
        supabase.table("catalog_settings")
        .select("business_id,slug,is_public,selected_product_ids")
        .eq("slug", catalog_slug)
        .eq("is_public", True)
        .limit(1)
        .execute()
    )
    if not catalog_response.data:
        raise HTTPException(status_code=404, detail="Public catalog not found")
    catalog = catalog_response.data[0]
    business_id = str(catalog["business_id"])
    target: str
    if requested.destination == "whatsapp":
        config_response = (
            supabase.table("whatsapp_order_settings")
            .select("phone_number")
            .eq("business_id", business_id)
            .limit(1)
            .execute()
        )
        phone_number = (
            config_response.data[0].get("phone_number") if config_response.data else None
        )
        if not phone_number:
            raise HTTPException(status_code=404, detail="WhatsApp ordering is not configured")
        phone_digits = re.sub(r"\D", "", str(phone_number))
        target = (
            f"https://wa.me/{phone_digits}"
            "?text=Hi%2C%20I%20found%20you%20on%20Instagram%20and%20would%20like%20to%20order."
        )
    else:
        selected_ids = [str(value) for value in catalog.get("selected_product_ids") or []]
        if requested.destination == "product":
            if requested.product_id not in selected_ids:
                raise HTTPException(status_code=404, detail="Product is not in this catalog")
            product = (
                supabase.table("products")
                .select("id")
                .eq("id", requested.product_id)
                .eq("user_id", business_id)
                .eq("is_active", True)
                .limit(1)
                .execute()
            )
            if not product.data:
                raise HTTPException(status_code=404, detail="Product is not available")
        web_base = (settings.PUBLIC_CATALOG_BASE_URL or "").strip().rstrip("/")
        if not web_base:
            raise HTTPException(
                status_code=503,
                detail="Public catalog base URL is not configured",
            )
        target = f"{web_base}/#/catalog/{catalog_slug}"
        if requested.destination == "product":
            target += f"?product={quote(requested.product_id or '')}"

    supabase.table("instagram_redirect_clicks").insert(
        {
            "business_id": business_id,
            "catalog_slug": catalog_slug,
            "destination": requested.destination,
            "tracking_tag": requested.tag,
            "product_id": requested.product_id,
            "created_at": _now(),
        }
    ).execute()
    return RedirectResponse(url=target, status_code=307)


@webhook_router.get("")
def verify_instagram_webhook(
    mode: str | None = Query(default=None, alias="hub.mode"),
    verify_token: str | None = Query(default=None, alias="hub.verify_token"),
    challenge: str | None = Query(default=None, alias="hub.challenge"),
):
    if (
        mode == "subscribe"
        and settings.VERIFY_TOKEN
        and verify_token
        and hmac.compare_digest(verify_token, settings.VERIFY_TOKEN)
    ):
        return PlainTextResponse(content=challenge or "")
    raise HTTPException(status_code=403, detail="Instagram webhook verification failed")


@webhook_router.post("")
async def receive_instagram_webhook(
    request: Request,
    x_hub_signature_256: str | None = Header(default=None),
):
    raw_body = await request.body()
    if not settings.META_APP_SECRET:
        raise HTTPException(
            status_code=503,
            detail="Meta app secret is not configured for webhook verification",
        )
    expected_signature = "sha256=" + hmac.new(
        settings.META_APP_SECRET.encode(),
        raw_body,
        hashlib.sha256,
    ).hexdigest()
    if not x_hub_signature_256 or not hmac.compare_digest(
        expected_signature,
        x_hub_signature_256,
    ):
        raise HTTPException(status_code=401, detail="Invalid Instagram webhook signature")

    try:
        payload = await request.json()
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid Instagram webhook JSON") from error

    for entry in payload.get("entry") or []:
        instagram_user_id = str(entry.get("id") or "")
        profile_response = (
            supabase.table("profiles")
            .select("id")
            .eq("instagram_user_id", instagram_user_id)
            .limit(1)
            .execute()
        )
        if not profile_response.data:
            continue
        business_id = str(profile_response.data[0]["id"])
        config = _get_config(business_id)
        if not config or not config.get("is_enabled"):
            continue
        for event in entry.get("messaging") or []:
            message = event.get("message") or {}
            message_id = str(message.get("mid") or "")
            text = str(message.get("text") or "").strip()
            sender_id = str((event.get("sender") or {}).get("id") or "")
            if not message_id or not text or not sender_id:
                continue
            if event.get("recipient", {}).get("id") and str(
                event["recipient"]["id"]
            ) != instagram_user_id:
                continue
            inserted = (
                supabase.table("instagram_auto_reply_events")
                .upsert(
                    {
                        "message_id": message_id,
                        "business_id": business_id,
                        "created_at": _now(),
                    },
                    on_conflict="business_id,message_id",
                    ignore_duplicates=True,
                )
                .select("message_id")
                .execute()
            )
            if not inserted.data:
                continue
            keywords = [
                str(keyword).casefold()
                for keyword in config.get("trigger_keywords") or []
            ]
            folded_text = text.casefold()
            if not any(keyword in folded_text for keyword in keywords):
                continue
            links = _tracked_links(business_id, "auto_reply")
            if not links["catalog"] or not links["whatsapp"]:
                continue
            reply = str(config.get("reply_text") or DEFAULT_REPLY)
            reply = reply.replace("{catalog_link}", links["catalog"])
            reply = reply.replace("{whatsapp_link}", links["whatsapp"])
            token = settings.INSTAGRAM_ACCESS_TOKEN
            if not token:
                continue
            try:
                response = httpx.post(
                    f"{GRAPH_API_BASE}/{instagram_user_id}/messages",
                    headers={"Authorization": f"Bearer {token}"},
                    json={
                        "recipient": {"id": sender_id},
                        "message": {"text": reply},
                    },
                    timeout=20,
                )
                if response.is_error:
                    (
                        supabase.table("instagram_auto_reply_events")
                        .update(
                            {
                                "reply_error": response.text,
                                "replied_at": _now(),
                            }
                        )
                        .eq("message_id", message_id)
                        .eq("business_id", business_id)
                        .execute()
                    )
                else:
                    (
                        supabase.table("instagram_auto_reply_events")
                        .update(
                            {
                                "reply_text": reply,
                                "replied_at": _now(),
                            }
                        )
                        .eq("message_id", message_id)
                        .eq("business_id", business_id)
                        .execute()
                    )
            except httpx.RequestError as error:
                (
                    supabase.table("instagram_auto_reply_events")
                    .update(
                        {
                            "reply_error": str(error),
                            "replied_at": _now(),
                        }
                    )
                    .eq("message_id", message_id)
                    .eq("business_id", business_id)
                    .execute()
                )
    return {"status": "received"}
