from typing import Any

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from core.config import settings
from core.supabase import supabase


bearer_scheme = HTTPBearer(auto_error=False)


def _safe_error_detail(error: Exception) -> str:
    if settings.ENVIRONMENT.lower() in {"local", "development", "dev"}:
        return f"Invalid or expired token: {str(error)}"

    return "Invalid or expired token"


def _user_id(user: Any) -> str:
    user_id = getattr(user, "id", None)

    if user_id:
        return str(user_id)

    if isinstance(user, dict) and user.get("id"):
        return str(user["id"])

    raise HTTPException(status_code=401, detail="Invalid user object")


def _user_metadata(user: Any) -> dict[str, Any]:
    metadata = getattr(user, "user_metadata", None)

    if isinstance(metadata, dict):
        return metadata

    if isinstance(user, dict) and isinstance(user.get("user_metadata"), dict):
        return user["user_metadata"]

    return {}


def get_logged_in_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
):
    if credentials is None:
        raise HTTPException(status_code=401, detail="Missing authorization header")

    token = credentials.credentials

    if not token:
        raise HTTPException(status_code=401, detail="Missing token")

    try:
        response = supabase.auth.get_user(token)

        if not response.user:
            raise HTTPException(status_code=401, detail="Invalid token")

        ensure_profile_exists(response.user)

        return response.user

    except HTTPException:
        raise

    except Exception as error:
        raise HTTPException(
            status_code=401,
            detail=_safe_error_detail(error),
        )


def get_current_user_id(
    user=Depends(get_logged_in_user),
) -> str:
    return _user_id(user)


def ensure_profile_exists(user: Any) -> None:
    uid = _user_id(user)
    metadata = _user_metadata(user)

    profile_response = (
        supabase.table("profiles")
        .select("id")
        .eq("id", uid)
        .execute()
    )

    if profile_response.data:
        return

    business_name = (
        metadata.get("business_name")
        or metadata.get("businessName")
        or "OrdiFy Business"
    )

    instagram_handle = (
        metadata.get("instagram_handle")
        or metadata.get("instagramHandle")
        or f"ordify_{uid[:8]}"
    )

    instagram_handle = str(instagram_handle).replace("@", "").strip()

    if not instagram_handle:
        instagram_handle = f"ordify_{uid[:8]}"

    supabase.table("profiles").insert(
        {
            "id": uid,
            "business_name": str(business_name).strip() or "OrdiFy Business",
            "instagram_handle": instagram_handle,
        }
    ).execute()