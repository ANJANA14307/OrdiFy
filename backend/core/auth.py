from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from core.supabase import supabase


bearer_scheme = HTTPBearer(auto_error=False)


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

        return response.user

    except Exception as e:
        raise HTTPException(
            status_code=401,
            detail=f"Invalid or expired token: {str(e)}",
        )


def ensure_profile_exists(user):
    profile_response = (
        supabase.table("profiles")
        .select("id")
        .eq("id", user.id)
        .execute()
    )

    if profile_response.data:
        return

    metadata = user.user_metadata or {}

    business_name = metadata.get("business_name") or "OrdiFy Business"
    instagram_handle = metadata.get("instagram_handle") or f"ordify_{str(user.id)[:8]}"

    supabase.table("profiles").insert(
        {
            "id": user.id,
            "business_name": business_name,
            "instagram_handle": instagram_handle,
        }
    ).execute()