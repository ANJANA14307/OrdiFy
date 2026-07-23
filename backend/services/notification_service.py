from typing import Any

from core.supabase import supabase


def create_notification(
    user_id: str,
    title: str,
    message: str,
    notification_type: str = "info",
    entity_type: str | None = None,
    entity_id: str | None = None,
):
    if notification_type not in ["info", "success", "warning", "error"]:
        notification_type = "info"

    payload: dict[str, Any] = {
        "user_id": user_id,
        "title": title,
        "message": message,
        "type": notification_type,
        "entity_type": entity_type,
        "entity_id": entity_id,
        "is_read": False,
    }

    try:
        response = supabase.table("notifications").insert(payload).execute()

        if not response.data:
            return None

        return response.data[0]
    except Exception:
        return None