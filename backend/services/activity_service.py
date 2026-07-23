from typing import Any

from core.supabase import supabase


def create_activity_log(
    user_id: str,
    action: str,
    description: str,
    entity_type: str | None = None,
    entity_id: str | None = None,
    metadata: dict[str, Any] | None = None,
):
    payload = {
        "user_id": user_id,
        "action": action,
        "description": description,
        "entity_type": entity_type,
        "entity_id": entity_id,
        "metadata": metadata or {},
    }

    try:
        response = supabase.table("activity_logs").insert(payload).execute()

        if not response.data:
            return None

        return response.data[0]
    except Exception:
        return None