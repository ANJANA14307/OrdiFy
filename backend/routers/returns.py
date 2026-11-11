from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query

from core.auth import get_logged_in_user
from core.supabase import supabase
from routers.orders import fetch_order, fetch_order_items, get_user_id
from schemas.returns import ReturnAction, ReturnPolicyUpdate, ReturnRequestCreate


router = APIRouter(prefix="/returns", tags=["Returns"])

ACTIVE_RETURN_STATUSES = {
    "return_requested",
    "approved",
    "item_received",
    "inspected",
}


def _policy(business_id: str) -> dict | None:
    response = (
        supabase.table("return_policies")
        .select("*")
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None


def _return_request(return_id: str, business_id: str) -> dict:
    response = (
        supabase.table("return_requests")
        .select("*")
        .eq("id", return_id)
        .eq("business_id", business_id)
        .limit(1)
        .execute()
    )
    if not response.data:
        raise HTTPException(status_code=404, detail="Return request not found")
    return response.data[0]


def _update_return(
    return_id: str,
    business_id: str,
    expected_status: str,
    values: dict[str, Any],
) -> dict:
    response = (
        supabase.table("return_requests")
        .update({**values, "updated_at": datetime.now(timezone.utc).isoformat()})
        .eq("id", return_id)
        .eq("business_id", business_id)
        .eq("status", expected_status)
        .select("*")
        .execute()
    )
    if not response.data:
        raise HTTPException(
            status_code=409,
            detail="Return status changed. Refresh and try again.",
        )
    return response.data[0]


def _delivery_timestamp(order: dict) -> datetime | None:
    value = order.get("updated_at")
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed
    except ValueError:
        return None


def _return_eligibility(order_id: str, business_id: str) -> dict:
    order = fetch_order(order_id, business_id)
    if order.get("status") != "delivered":
        return {
            "eligible": False,
            "reason": "Returns can only be requested for delivered orders.",
            "items": [],
            "existing_return": None,
        }

    policy = _policy(business_id)
    if policy is None:
        return {
            "eligible": False,
            "reason": "This business has not configured a return policy.",
            "items": [],
            "existing_return": None,
        }

    cutoff = _delivery_timestamp(order)
    if cutoff is None or datetime.now(timezone.utc) - cutoff > timedelta(
        days=int(policy["return_window_days"])
    ):
        return {
            "eligible": False,
            "reason": "The return window has expired.",
            "items": [],
            "existing_return": None,
        }

    request_response = (
        supabase.table("return_requests")
        .select("id,status,items")
        .eq("business_id", business_id)
        .eq("order_id", order_id)
        .order("requested_at", desc=True)
        .execute()
    )
    prior = request_response.data or []
    current = next(
        (request for request in prior if request.get("status") in ACTIVE_RETURN_STATUSES),
        None,
    )
    if current:
        return {
            "eligible": False,
            "reason": "A return request already exists for this order.",
            "items": [],
            "existing_return": current,
        }

    non_returnable = {str(value) for value in policy.get("non_returnable_product_ids") or []}
    order_items = fetch_order_items(order_id)
    items = []
    for item in order_items:
        product_id = str(item.get("product_id") or "")
        remaining_quantity = int(item.get("quantity") or 0)
        product_response = (
            supabase.table("products")
            .select("name")
            .eq("id", product_id)
            .eq("user_id", business_id)
            .limit(1)
            .execute()
        )
        product_name = (
            product_response.data[0].get("name")
            if product_response.data
            else "Product"
        )
        for request in prior:
            if request.get("status") == "rejected":
                continue
            for returned_item in request.get("items") or []:
                if str(returned_item.get("order_item_id")) == str(item.get("id")):
                    accepted_quantity = returned_item.get("accepted_quantity")
                    returned_quantity = (
                        int(accepted_quantity)
                        if accepted_quantity is not None
                        else int(returned_item.get("quantity") or 0)
                    )
                    remaining_quantity -= returned_quantity
        is_eligible = product_id not in non_returnable and remaining_quantity > 0
        items.append(
            {
                "order_item_id": str(item.get("id")),
                "product_id": product_id,
                "product_name": str(product_name or "Product"),
                "variant_code": str(item.get("variant_notes") or ""),
                "unit_price": float(item.get("unit_price") or 0),
                "quantity": max(remaining_quantity, 0),
                "eligible": is_eligible,
                "ineligible_reason": (
                    "This product is not returnable."
                    if product_id in non_returnable
                    else None
                ),
            }
        )

    eligible = any(item["eligible"] for item in items)
    return {
        "eligible": eligible,
        "reason": None if eligible else "No eligible items remain in this order.",
        "items": items,
        "existing_return": None,
        "policy": {
            "return_window_days": policy["return_window_days"],
            "eligible_conditions": policy.get("eligible_conditions") or [],
            "allow_refund": policy.get("allow_refund", True),
            "allow_exchange": policy.get("allow_exchange", True),
            "policy_text": policy.get("policy_text", ""),
        },
    }


@router.get("/policy")
def get_return_policy(user=Depends(get_logged_in_user)):
    return {"policy": _policy(get_user_id(user))}


@router.put("/policy")
def save_return_policy(
    payload: ReturnPolicyUpdate,
    user=Depends(get_logged_in_user),
):
    business_id = get_user_id(user)
    if payload.non_returnable_product_ids:
        owned_products = (
            supabase.table("products")
            .select("id")
            .eq("user_id", business_id)
            .in_("id", payload.non_returnable_product_ids)
            .execute()
            .data
            or []
        )
        owned_ids = {str(product["id"]) for product in owned_products}
        if owned_ids != set(payload.non_returnable_product_ids):
            raise HTTPException(
                status_code=422,
                detail="Non-returnable products must belong to this business",
            )
    policy_data = {
        **payload.model_dump(),
        "business_id": business_id,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    try:
        response = (
            supabase.table("return_policies")
            .upsert(policy_data, on_conflict="business_id")
            .select("*")
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Return policy could not be saved: {error}",
        ) from error
    if not response.data:
        raise HTTPException(status_code=500, detail="Return policy could not be saved")
    return {"policy": response.data[0]}


@router.get("/orders/{order_id}/eligibility")
def get_order_return_eligibility(
    order_id: str,
    user=Depends(get_logged_in_user),
):
    return _return_eligibility(order_id, get_user_id(user))


@router.post("/orders/{order_id}")
def create_return_request(
    order_id: str,
    payload: ReturnRequestCreate,
    user=Depends(get_logged_in_user),
):
    business_id = get_user_id(user)
    eligibility = _return_eligibility(order_id, business_id)
    if not eligibility["eligible"]:
        raise HTTPException(
            status_code=409,
            detail=eligibility.get("reason") or "This order is not eligible for return.",
        )

    available = {item["order_item_id"]: item for item in eligibility["items"]}
    selected_ids = [item.order_item_id for item in payload.items]
    if len(set(selected_ids)) != len(selected_ids):
        raise HTTPException(status_code=422, detail="Each order item may be selected once")
    policy = eligibility.get("policy") or {}
    if payload.preferred_outcome == "refund" and not policy.get("allow_refund", True):
        raise HTTPException(status_code=422, detail="Refunds are not allowed by this policy")
    if payload.preferred_outcome == "exchange" and not policy.get("allow_exchange", True):
        raise HTTPException(status_code=422, detail="Exchanges are not allowed by this policy")

    request_items = []
    for selected in payload.items:
        item = available.get(selected.order_item_id)
        if item is None or not item["eligible"]:
            raise HTTPException(status_code=422, detail="Selected product is not eligible for return")
        if selected.quantity > item["quantity"]:
            raise HTTPException(status_code=422, detail="Return quantity exceeds the eligible quantity")
        request_items.append(
            {
                **item,
                "quantity": selected.quantity,
                "accepted_quantity": None,
            }
        )

    try:
        response = supabase.rpc(
            "create_return_request",
            {
                "p_business_id": business_id,
                "p_order_id": order_id,
                "p_items": request_items,
                "p_reason": payload.reason,
                "p_comment": payload.comment,
                "p_photos": payload.photos,
                "p_preferred_outcome": payload.preferred_outcome,
            },
        ).execute()
    except Exception as error:
        detail = str(error)
        lowered_detail = detail.lower()
        code = 409 if "conflict" in lowered_detail or "already exists" in lowered_detail else 422
        raise HTTPException(
            status_code=code,
            detail=f"Return request could not be created: {detail}",
        ) from error
    data = response.data
    if isinstance(data, list):
        data = data[0] if data else None
    if not data:
        raise HTTPException(status_code=500, detail="Return request could not be created")
    return {"return_request": data}


@router.get("")
def list_return_requests(
    status: str | None = Query(default=None),
    search: str | None = Query(default=None, max_length=100),
    user=Depends(get_logged_in_user),
):
    business_id = get_user_id(user)
    query = (
        supabase.table("return_requests")
        .select("*")
        .eq("business_id", business_id)
        .order("requested_at", desc=True)
    )
    if status:
        valid_statuses = {
            "return_requested",
            "approved",
            "item_received",
            "inspected",
            "refund_issued",
            "exchange_created",
            "rejected",
        }
        if status not in valid_statuses:
            raise HTTPException(status_code=400, detail="Invalid return status")
        query = query.eq("status", status)
    response = query.execute()
    requests = response.data or []
    if search:
        needle = search.casefold()
        requests = [
            item
            for item in requests
            if needle in str(item.get("order_id", "")).casefold()
            or any(
                needle in str(returned_item.get("product_name", "")).casefold()
                for returned_item in item.get("items") or []
            )
        ]
    return {"returns": requests}


@router.get("/{return_id}")
def get_return_request(return_id: str, user=Depends(get_logged_in_user)):
    return {"return_request": _return_request(return_id, get_user_id(user))}


@router.post("/{return_id}/actions")
def act_on_return_request(
    return_id: str,
    payload: ReturnAction,
    user=Depends(get_logged_in_user),
):
    business_id = get_user_id(user)
    request = _return_request(return_id, business_id)
    current_status = request["status"]
    now = datetime.now(timezone.utc).isoformat()
    message = payload.notes or payload.reason or payload.action.replace("_", " ").title()
    timeline = list(request.get("messages") or [])
    timeline.append({"status": payload.action, "message": message, "at": now})

    if payload.action == "approve":
        if current_status != "return_requested":
            raise HTTPException(status_code=409, detail="Only requested returns can be approved")
        updated = _update_return(
            return_id, business_id, current_status,
            {"status": "approved", "messages": timeline},
        )
    elif payload.action == "reject":
        if current_status not in {"return_requested", "approved"}:
            raise HTTPException(status_code=409, detail="This return can no longer be rejected")
        updated = _update_return(
            return_id, business_id, current_status,
            {
                "status": "rejected",
                "rejection_reason": payload.reason or "Return rejected",
                "messages": timeline,
            },
        )
    elif payload.action == "mark_received":
        if current_status != "approved":
            raise HTTPException(status_code=409, detail="Only approved returns can be marked received")
        updated = _update_return(
            return_id, business_id, current_status,
            {"status": "item_received", "messages": timeline},
        )
    elif payload.action == "inspect":
        if current_status != "item_received":
            raise HTTPException(status_code=409, detail="Only received items can be inspected")
        requested_items = {
            str(item.get("order_item_id")): int(item.get("quantity") or 0)
            for item in request.get("items") or []
        }
        inspected_ids = [item.order_item_id for item in payload.inspected_items]
        if len(set(inspected_ids)) != len(inspected_ids) or set(inspected_ids) != set(
            requested_items
        ):
            raise HTTPException(
                status_code=422,
                detail="Inspection must include each requested item exactly once",
            )
        total_requested = sum(requested_items.values())
        total_accepted = 0
        for item in payload.inspected_items:
            if item.accepted_quantity > requested_items[item.order_item_id]:
                raise HTTPException(
                    status_code=422,
                    detail="Accepted quantity cannot exceed the requested quantity",
                )
            total_accepted += item.accepted_quantity
        if payload.inspection_result == "accepted" and total_accepted != total_requested:
            raise HTTPException(
                status_code=422,
                detail="All requested quantities must be accepted",
            )
        if payload.inspection_result == "partially_accepted" and (
            total_accepted == 0 or total_accepted == total_requested
        ):
            raise HTTPException(
                status_code=422,
                detail="Partial inspection must accept some, but not all, items",
            )
        if payload.inspection_result == "rejected" and total_accepted != 0:
            raise HTTPException(
                status_code=422,
                detail="Rejected inspection cannot accept any quantity",
            )
        inspected_items = [item.model_dump() for item in payload.inspected_items]
        try:
            result = supabase.rpc(
                "inspect_return_request",
                {
                    "p_return_id": return_id,
                    "p_business_id": business_id,
                    "p_inspection_result": payload.inspection_result,
                    "p_inspected_items": inspected_items,
                    "p_notes": payload.notes,
                    "p_photos": payload.photos,
                },
            ).execute()
        except Exception as error:
            detail = str(error)
            code = 409 if any(
                phrase in detail.lower()
                for phrase in ("status conflict", "return request not found")
            ) else 500
            raise HTTPException(
                status_code=code,
                detail=f"Return inspection failed: {detail}",
            ) from error
        data = result.data
        if isinstance(data, list):
            data = data[0] if data else None
        if not data:
            raise HTTPException(status_code=500, detail="Return inspection returned no result")
        inspected_status = str(data.get("status") or "inspected")
        timeline.append(
            {
                "status": inspected_status,
                "message": message,
                "at": now,
            }
        )
        updated = _update_return(
            return_id, business_id, inspected_status, {"messages": timeline}
        )
    elif payload.action == "issue_refund":
        if current_status != "inspected":
            raise HTTPException(status_code=409, detail="Only inspected returns can be refunded")
        if request.get("inspection_result") == "rejected":
            raise HTTPException(status_code=409, detail="Rejected items cannot be refunded")
        policy = _policy(business_id) or {}
        if not policy.get("allow_refund", True):
            raise HTTPException(status_code=409, detail="Refunds are disabled by the return policy")
        maximum = sum(
            float(item.get("unit_price") or 0) * int(item.get("accepted_quantity") or 0)
            for item in request.get("items") or []
        )
        if payload.refund_amount is None or payload.refund_amount > maximum:
            raise HTTPException(
                status_code=422,
                detail=f"Refund cannot exceed the accepted item value ({maximum:.2f})",
            )
        updated = _update_return(
            return_id, business_id, current_status,
            {
                "status": "refund_issued",
                "refund_amount": payload.refund_amount,
                "messages": timeline,
            },
        )
    else:
        if current_status != "inspected":
            raise HTTPException(status_code=409, detail="Only inspected returns can be exchanged")
        if request.get("inspection_result") == "rejected":
            raise HTTPException(status_code=409, detail="Rejected items cannot be exchanged")
        policy = _policy(business_id) or {}
        if not policy.get("allow_exchange", True):
            raise HTTPException(status_code=409, detail="Exchanges are disabled by the return policy")
        try:
            exchange_response = supabase.rpc(
                "create_return_exchange",
                {"p_return_id": return_id, "p_business_id": business_id},
            ).execute()
        except Exception as error:
            raise HTTPException(
                status_code=500,
                detail=f"Exchange order could not be created: {error}",
            ) from error
        exchange_data = exchange_response.data
        if isinstance(exchange_data, list):
            exchange_data = exchange_data[0] if exchange_data else None
        if not exchange_data:
            raise HTTPException(status_code=500, detail="Exchange order returned no result")
        updated = _return_request(return_id, business_id)

    return {"return_request": updated}
