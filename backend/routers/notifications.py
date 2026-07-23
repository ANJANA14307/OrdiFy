from fastapi import APIRouter, Depends, HTTPException

from core.auth import get_logged_in_user
from core.supabase import supabase


router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("")
def get_notifications(
    unread_only: bool = False,
    limit: int = 30,
    user=Depends(get_logged_in_user),
):
    query = (
        supabase.table("notifications")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", desc=True)
        .limit(limit)
    )

    if unread_only:
        query = query.eq("is_read", False)

    response = query.execute()

    notifications = response.data or []

    return {
        "notifications": notifications,
        "count": len(notifications),
    }


@router.get("/unread-count")
def get_unread_notification_count(
    user=Depends(get_logged_in_user),
):
    response = (
        supabase.table("notifications")
        .select("id")
        .eq("user_id", user.id)
        .eq("is_read", False)
        .execute()
    )

    notifications = response.data or []

    return {
        "unread_count": len(notifications),
    }


@router.patch("/mark-all-read")
def mark_all_notifications_as_read(
    user=Depends(get_logged_in_user),
):
    response = (
        supabase.table("notifications")
        .update({"is_read": True})
        .eq("user_id", user.id)
        .eq("is_read", False)
        .execute()
    )

    return {
        "message": "All notifications marked as read",
        "updated": response.data or [],
    }


@router.patch("/{notification_id}/read")
def mark_notification_as_read(
    notification_id: str,
    user=Depends(get_logged_in_user),
):
    response = (
        supabase.table("notifications")
        .update({"is_read": True})
        .eq("id", notification_id)
        .eq("user_id", user.id)
        .execute()
    )

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail="Notification not found",
        )

    return {
        "message": "Notification marked as read",
        "notification": response.data[0],
    }


@router.delete("/{notification_id}")
def delete_notification(
    notification_id: str,
    user=Depends(get_logged_in_user),
):
    response = (
        supabase.table("notifications")
        .delete()
        .eq("id", notification_id)
        .eq("user_id", user.id)
        .execute()
    )

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail="Notification not found",
        )

    return {
        "message": "Notification deleted",
    }