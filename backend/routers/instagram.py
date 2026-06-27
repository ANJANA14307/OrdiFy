from datetime import datetime, timezone
from typing import Any, Optional, List

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel, Field
import httpx

from core.config import settings
from core.supabase import supabase


router = APIRouter(
    prefix="/instagram",
    tags=["Instagram"],
)

INSTAGRAM_GRAPH_API_BASE = "https://graph.instagram.com/v22.0"


class DmOrderItemCreate(BaseModel):
    product_id: str
    quantity: int = Field(gt=0)
    unit_price: Optional[float] = Field(default=None, gt=0)
    variant_notes: Optional[str] = None


class CreateOrderFromDmRequest(BaseModel):
    thread_id: str
    message_ids: List[str] = []
    instagram_username: Optional[str] = None
    display_name: Optional[str] = None
    notes: Optional[str] = None
    custom_variant: Optional[str] = None
    items: List[DmOrderItemCreate]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def get_instagram_access_token() -> str:
    access_token = settings.INSTAGRAM_ACCESS_TOKEN

    if not access_token:
        raise HTTPException(
            status_code=500,
            detail="Instagram access token is not configured",
        )

    return access_token


async def fetch_instagram_profile():
    access_token = get_instagram_access_token()

    url = "https://graph.instagram.com/me"

    params = {
        "fields": "user_id,username",
        "access_token": access_token,
    }

    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.get(url, params=params)

    if response.status_code != 200:
        raise HTTPException(
            status_code=response.status_code,
            detail=response.json(),
        )

    return response.json()


async def call_instagram_graph(
    path: str,
    params: Optional[dict[str, Any]] = None,
):
    access_token = get_instagram_access_token()

    clean_path = path if path.startswith("/") else f"/{path}"

    url = f"{INSTAGRAM_GRAPH_API_BASE}{clean_path}"

    request_params = params.copy() if params else {}
    request_params["access_token"] = access_token

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.get(url, params=request_params)

    if response.status_code != 200:
        try:
            error_body = response.json()
        except Exception:
            error_body = response.text

        raise HTTPException(
            status_code=response.status_code,
            detail={
                "message": "Instagram API rejected the request",
                "meta_error": error_body,
            },
        )

    return response.json()


def get_logged_in_user(authorization: str | None):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="Missing authentication token",
        )

    user_token = authorization.replace("Bearer ", "")

    try:
        user_response = supabase.auth.get_user(user_token)
        user = user_response.user
    except Exception:
        raise HTTPException(
            status_code=401,
            detail="Invalid authentication token",
        )

    if not user:
        raise HTTPException(
            status_code=401,
            detail="User not found",
        )

    return user


def get_profile_for_user(user_id: str):
    response = (
        supabase.table("profiles")
        .select(
            "id, business_name, instagram_user_id, instagram_username, instagram_connected_at"
        )
        .eq("id", user_id)
        .execute()
    )

    if not response.data:
        return None

    return response.data[0]


def require_connected_instagram(user_id: str):
    profile = get_profile_for_user(user_id)

    if not profile or not profile.get("instagram_user_id"):
        raise HTTPException(
            status_code=400,
            detail="Instagram is not connected for this user",
        )

    return profile


async def fetch_instagram_user_profile(ig_scoped_id: str):
    if not ig_scoped_id:
        return None

    try:
        return await call_instagram_graph(
            f"/{ig_scoped_id}",
            params={
                "fields": "username,name,profile_pic",
            },
        )
    except HTTPException:
        return None


async def fetch_thread_raw(thread_id: str):
    return await call_instagram_graph(
        f"/{thread_id}",
        params={
            "fields": (
                "id,updated_time,"
                "messages.limit(50){id,created_time,from,to,message,attachments}"
            ),
        },
    )


def normalize_conversation(conversation: dict[str, Any]) -> dict[str, Any]:
    messages = conversation.get("messages") or {}
    message_data = messages.get("data") or []

    latest_message = message_data[0] if message_data else {}

    sender = latest_message.get("from") or {}
    sender_id = sender.get("id")
    sender_username = sender.get("username") or sender.get("name")

    return {
        "id": conversation.get("id"),
        "updated_time": conversation.get("updated_time"),
        "preview_message": latest_message.get("message"),
        "preview_message_id": latest_message.get("id"),
        "preview_sender_id": sender_id,
        "preview_sender_username": sender_username,
        "raw": conversation,
    }


def normalize_message(message: dict[str, Any]) -> dict[str, Any]:
    sender = message.get("from") or {}

    return {
        "id": message.get("id"),
        "created_time": message.get("created_time"),
        "message": message.get("message"),
        "from": sender,
        "to": message.get("to"),
        "attachments": message.get("attachments"),
        "raw": message,
    }


async def guess_customer_from_thread(
    thread_id: str,
    business_ig_user_id: str | None,
):
    thread = await fetch_thread_raw(thread_id)

    messages = (thread.get("messages") or {}).get("data") or []

    possible_sender_id = None
    possible_sender_name = None

    for message in messages:
        sender = message.get("from") or {}

        sender_id = sender.get("id")
        sender_name = sender.get("username") or sender.get("name")

        if sender_id and sender_id != business_ig_user_id:
            possible_sender_id = sender_id
            possible_sender_name = sender_name
            break

    if not possible_sender_id:
        return {
            "instagram_username": None,
            "display_name": None,
            "ig_scoped_id": None,
        }

    profile = await fetch_instagram_user_profile(possible_sender_id)

    if profile:
        return {
            "instagram_username": profile.get("username"),
            "display_name": profile.get("name"),
            "ig_scoped_id": possible_sender_id,
        }

    return {
        "instagram_username": possible_sender_name,
        "display_name": possible_sender_name,
        "ig_scoped_id": possible_sender_id,
    }


def get_or_create_customer(
    user_id: str,
    instagram_username: str,
    display_name: Optional[str],
):
    cleaned_username = instagram_username.strip().replace("@", "")

    if not cleaned_username:
        raise HTTPException(
            status_code=400,
            detail="Instagram username is required to create customer",
        )

    existing_response = (
        supabase.table("customers")
        .select("*")
        .eq("user_id", user_id)
        .eq("instagram_username", cleaned_username)
        .execute()
    )

    if existing_response.data:
        return existing_response.data[0]

    create_response = (
        supabase.table("customers")
        .insert(
            {
                "user_id": user_id,
                "instagram_username": cleaned_username,
                "display_name": display_name or cleaned_username,
            }
        )
        .execute()
    )

    if not create_response.data:
        raise HTTPException(
            status_code=500,
            detail="Customer could not be auto-created",
        )

    return create_response.data[0]


def fetch_product_for_order(user_id: str, product_id: str):
    response = (
        supabase.table("products")
        .select("*")
        .eq("id", product_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail=f"Product not found: {product_id}",
        )

    return response.data[0]


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


def validate_dm_order_items(
    user_id: str,
    items: list[DmOrderItemCreate],
):
    if not items:
        raise HTTPException(
            status_code=400,
            detail="At least one order item is required",
        )

    product_cache = {}
    quantity_by_product = {}

    for item in items:
        product = fetch_product_for_order(user_id, item.product_id)

        product_cache[item.product_id] = product
        quantity_by_product[item.product_id] = (
            quantity_by_product.get(item.product_id, 0) + item.quantity
        )

    for product_id, quantity in quantity_by_product.items():
        product = product_cache[product_id]
        stock_count = to_int(product.get("stock_count"))
        product_name = product.get("name") or "Product"

        if stock_count <= 0:
            raise HTTPException(
                status_code=400,
                detail=f"{product_name} is out of stock",
            )

        if quantity > stock_count:
            raise HTTPException(
                status_code=400,
                detail=f"Only {stock_count} available for {product_name}",
            )

    return product_cache


def build_order_detail(order: dict[str, Any]):
    customer = None
    customer_id = order.get("customer_id")

    if customer_id:
        customer_response = (
            supabase.table("customers")
            .select("*")
            .eq("id", customer_id)
            .execute()
        )

        if customer_response.data:
            customer = customer_response.data[0]

    item_response = (
        supabase.table("order_items")
        .select("*")
        .eq("order_id", order.get("id"))
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

    payment_response = (
        supabase.table("payments")
        .select("status")
        .eq("order_id", order.get("id"))
        .limit(1)
        .execute()
    )

    payment_status = "pending"

    if payment_response.data:
        payment_status = payment_response.data[0].get("status") or "pending"

    total_quantity = 0

    for item in detailed_items:
        total_quantity += to_int(item.get("quantity"))

    return {
        **order,
        "customer": customer,
        "items": detailed_items,
        "payment_status": payment_status,
        "item_count": len(detailed_items),
        "total_quantity": total_quantity,
    }


def update_customer_order_summary(
    customer_id: str,
    order_total: float,
):
    customer_response = (
        supabase.table("customers")
        .select("total_orders,total_spent")
        .eq("id", customer_id)
        .execute()
    )

    if not customer_response.data:
        return

    customer = customer_response.data[0]

    total_orders = to_int(customer.get("total_orders")) + 1
    total_spent = to_float(customer.get("total_spent")) + order_total

    (
        supabase.table("customers")
        .update(
            {
                "total_orders": total_orders,
                "total_spent": total_spent,
                "last_order_at": now_iso(),
            }
        )
        .eq("id", customer_id)
        .execute()
    )


@router.get("/profile")
async def get_instagram_profile():
    return await fetch_instagram_profile()


@router.get("/status")
async def get_instagram_status(
    authorization: str | None = Header(default=None),
):
    user = get_logged_in_user(authorization)

    response = (
        supabase.table("profiles")
        .select(
            "id, instagram_user_id, instagram_username, instagram_connected_at"
        )
        .eq("id", user.id)
        .execute()
    )

    if not response.data:
        return {
            "connected": False,
            "instagram": None,
        }

    profile = response.data[0]

    is_connected = profile.get("instagram_username") is not None

    return {
        "connected": is_connected,
        "instagram": {
            "user_id": profile.get("instagram_user_id"),
            "username": profile.get("instagram_username"),
            "connected_at": profile.get("instagram_connected_at"),
        }
        if is_connected
        else None,
    }


@router.post("/connect")
async def connect_instagram(
    authorization: str | None = Header(default=None),
):
    user = get_logged_in_user(authorization)

    instagram_profile = await fetch_instagram_profile()

    instagram_data = {
        "instagram_user_id": instagram_profile.get("user_id"),
        "instagram_username": instagram_profile.get("username"),
        "instagram_connected_at": now_iso(),
    }

    update_response = (
        supabase.table("profiles")
        .update(instagram_data)
        .eq("id", user.id)
        .select()
        .execute()
    )

    if update_response.data:
        return {
            "message": "Instagram connected successfully",
            "user_id": user.id,
            "instagram": {
                "user_id": instagram_profile.get("user_id"),
                "username": instagram_profile.get("username"),
            },
            "updated_profile": update_response.data[0],
        }

    metadata = user.user_metadata or {}

    business_name = metadata.get("business_name") or "OrdiFy Business"
    instagram_handle = metadata.get("instagram_handle") or f"ordify_{str(user.id)[:8]}"

    insert_response = (
        supabase.table("profiles")
        .insert(
            {
                "id": user.id,
                "business_name": business_name,
                "instagram_handle": instagram_handle,
                **instagram_data,
            }
        )
        .select()
        .execute()
    )

    if not insert_response.data:
        raise HTTPException(
            status_code=500,
            detail="Profile row could not be created",
        )

    return {
        "message": "Instagram connected successfully",
        "user_id": user.id,
        "instagram": {
            "user_id": instagram_profile.get("user_id"),
            "username": instagram_profile.get("username"),
        },
        "created_profile": insert_response.data[0],
    }


@router.get("/dms")
async def get_instagram_dms(
    authorization: str | None = Header(default=None),
):
    user = get_logged_in_user(authorization)
    profile = require_connected_instagram(user.id)

    instagram_user_id = profile.get("instagram_user_id")

    response = await call_instagram_graph(
        f"/{instagram_user_id}/conversations",
        params={
            "fields": (
                "id,updated_time,"
                "messages.limit(1){id,created_time,from,to,message}"
            ),
            "limit": 20,
        },
    )

    raw_conversations = response.get("data") or []

    conversations = [
        normalize_conversation(conversation)
        for conversation in raw_conversations
    ]

    return {
        "connected_instagram": {
            "user_id": profile.get("instagram_user_id"),
            "username": profile.get("instagram_username"),
        },
        "conversations": conversations,
        "paging": response.get("paging"),
        "count": len(conversations),
    }


@router.get("/dms/{thread_id}/messages")
async def get_instagram_dm_messages(
    thread_id: str,
    authorization: str | None = Header(default=None),
):
    user = get_logged_in_user(authorization)
    profile = require_connected_instagram(user.id)

    thread = await fetch_thread_raw(thread_id)

    raw_messages = (thread.get("messages") or {}).get("data") or []

    messages = [
        normalize_message(message)
        for message in raw_messages
    ]

    linked_order_response = (
        supabase.table("orders")
        .select("id,order_number,status,total_amount,created_at")
        .eq("user_id", user.id)
        .eq("instagram_thread_id", thread_id)
        .limit(1)
        .execute()
    )

    linked_order = linked_order_response.data[0] if linked_order_response.data else None

    return {
        "connected_instagram": {
            "user_id": profile.get("instagram_user_id"),
            "username": profile.get("instagram_username"),
        },
        "thread": {
            "id": thread.get("id") or thread_id,
            "updated_time": thread.get("updated_time"),
        },
        "messages": messages,
        "linked_order": linked_order,
        "count": len(messages),
    }


@router.post("/orders/from-dm")
async def create_order_from_dm(
    payload: CreateOrderFromDmRequest,
    authorization: str | None = Header(default=None),
):
    user = get_logged_in_user(authorization)
    profile = require_connected_instagram(user.id)

    instagram_username = payload.instagram_username
    display_name = payload.display_name

    if not instagram_username:
        guessed_customer = await guess_customer_from_thread(
            payload.thread_id,
            profile.get("instagram_user_id"),
        )

        instagram_username = guessed_customer.get("instagram_username")
        display_name = display_name or guessed_customer.get("display_name")

        if not instagram_username:
            ig_scoped_id = guessed_customer.get("ig_scoped_id")

            if ig_scoped_id:
                instagram_username = f"ig_user_{ig_scoped_id}"

    if not instagram_username:
        raise HTTPException(
            status_code=400,
            detail=(
                "Instagram username could not be detected from DM. "
                "Send instagram_username in request body."
            ),
        )

    customer = get_or_create_customer(
        user_id=user.id,
        instagram_username=instagram_username,
        display_name=display_name,
    )

    product_cache = validate_dm_order_items(
        user_id=user.id,
        items=payload.items,
    )

    total_amount = 0.0

    item_rows = []

    for item in payload.items:
        product = product_cache[item.product_id]

        unit_price = item.unit_price

        if unit_price is None:
            unit_price = to_float(product.get("price"))

        line_total = unit_price * item.quantity
        total_amount += line_total

        item_rows.append(
            {
                "product_id": item.product_id,
                "quantity": item.quantity,
                "unit_price": unit_price,
                "variant_notes": item.variant_notes,
            }
        )

    order_response = (
        supabase.table("orders")
        .insert(
            {
                "user_id": user.id,
                "customer_id": customer["id"],
                "status": "new",
                "source": "dm",
                "notes": payload.notes,
                "custom_variant": payload.custom_variant,
                "total_amount": total_amount,
                "instagram_thread_id": payload.thread_id,
                "instagram_message_ids": payload.message_ids,
            }
        )
        .execute()
    )

    if not order_response.data:
        raise HTTPException(
            status_code=500,
            detail="Order could not be created from DM",
        )

    order = order_response.data[0]

    order_item_rows = []

    for item_row in item_rows:
        order_item_rows.append(
            {
                "order_id": order["id"],
                **item_row,
            }
        )

    if order_item_rows:
        insert_items_response = (
            supabase.table("order_items")
            .insert(order_item_rows)
            .execute()
        )

        if not insert_items_response.data:
            raise HTTPException(
                status_code=500,
                detail="Order was created but order items could not be inserted",
            )

    update_customer_order_summary(
        customer_id=customer["id"],
        order_total=total_amount,
    )

    detailed_order = build_order_detail(order)

    return {
        "message": "Order created from Instagram DM successfully",
        "customer_auto_created_or_linked": customer,
        "order": detailed_order,
    }