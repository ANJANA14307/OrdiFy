from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from core.auth import get_logged_in_user
from core.supabase import supabase


router = APIRouter(prefix="/profile", tags=["Profile"])


class UpdateProfileRequest(BaseModel):
    business_name: str | None = Field(
        default=None,
        min_length=1,
        max_length=120,
    )
    instagram_handle: str | None = Field(
        default=None,
        max_length=80,
    )
    avatar_url: str | None = Field(
        default=None,
        max_length=1000,
    )


def get_user_id(user) -> str:
    user_id = getattr(user, "id", None)

    if user_id:
        return str(user_id)

    if isinstance(user, dict) and user.get("id"):
        return str(user["id"])

    raise HTTPException(
        status_code=401,
        detail="Invalid user account",
    )


def get_user_email(user) -> str | None:
    email = getattr(user, "email", None)

    if email:
        return str(email)

    if isinstance(user, dict):
        value = user.get("email")

        if value:
            return str(value)

    return None


def clean_optional_text(value: str | None) -> str | None:
    if value is None:
        return None

    cleaned = value.strip()

    return cleaned or None


def clean_instagram_handle(value: str | None) -> str | None:
    cleaned = clean_optional_text(value)

    if cleaned is None:
        return None

    cleaned = cleaned.replace("@", "").strip()

    if " " in cleaned:
        raise HTTPException(
            status_code=400,
            detail="Instagram username cannot contain spaces",
        )

    return cleaned or None


def fetch_profile(user_id: str):
    try:
        response = (
            supabase.table("profiles")
            .select("*")
            .eq("id", user_id)
            .limit(1)
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Profile could not be loaded: {str(error)}",
        )

    if not response.data:
        return None

    return response.data[0]


def create_default_profile(user):
    user_id = get_user_id(user)

    metadata = getattr(user, "user_metadata", None)

    if not isinstance(metadata, dict):
        metadata = {}

    business_name = (
        metadata.get("business_name")
        or metadata.get("businessName")
        or "My Business"
    )

    instagram_handle = (
        metadata.get("instagram_handle")
        or metadata.get("instagramHandle")
        or f"ordify_{user_id[:8]}"
    )

    instagram_handle = str(instagram_handle).replace("@", "").strip()

    try:
        response = (
            supabase.table("profiles")
            .insert(
                {
                    "id": user_id,
                    "business_name": str(business_name).strip() or "My Business",
                    "instagram_handle": instagram_handle,
                    "plan_tier": "free",
                }
            )
            .select()
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Profile could not be created: {str(error)}",
        )

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Profile could not be created",
        )

    return response.data[0]


@router.get("/me")
def get_my_profile(user=Depends(get_logged_in_user)):
    user_id = get_user_id(user)

    profile = fetch_profile(user_id)

    if profile is None:
        profile = create_default_profile(user)

    return {
        "id": profile.get("id"),
        "business_name": profile.get("business_name") or "My Business",
        "instagram_handle": profile.get("instagram_handle"),
        "avatar_url": profile.get("avatar_url"),
        "plan_tier": profile.get("plan_tier") or "free",
        "created_at": profile.get("created_at"),
        "email": get_user_email(user),
    }


@router.patch("/me")
def update_my_profile(
    payload: UpdateProfileRequest,
    user=Depends(get_logged_in_user),
):
    user_id = get_user_id(user)

    existing_profile = fetch_profile(user_id)

    if existing_profile is None:
        create_default_profile(user)

    update_data = payload.model_dump(exclude_unset=True)

    if "business_name" in update_data:
        business_name = clean_optional_text(update_data["business_name"])

        if business_name is None:
            raise HTTPException(
                status_code=400,
                detail="Business name is required",
            )

        update_data["business_name"] = business_name

    if "instagram_handle" in update_data:
        update_data["instagram_handle"] = clean_instagram_handle(
            update_data["instagram_handle"]
        )

    if "avatar_url" in update_data:
        update_data["avatar_url"] = clean_optional_text(
            update_data["avatar_url"]
        )

    if not update_data:
        raise HTTPException(
            status_code=400,
            detail="No changes were provided",
        )

    try:
        response = (
            supabase.table("profiles")
            .update(update_data)
            .eq("id", user_id)
            .select()
            .execute()
        )
    except Exception as error:
        error_text = str(error).lower()

        if "duplicate" in error_text or "unique" in error_text:
            raise HTTPException(
                status_code=400,
                detail="This Instagram username is already being used",
            )

        raise HTTPException(
            status_code=500,
            detail=f"Profile could not be updated: {str(error)}",
        )

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Profile could not be updated",
        )

    profile = response.data[0]

    return {
        "updated": True,
        "message": "Profile updated successfully",
        "profile": {
            **profile,
            "email": get_user_email(user),
        },
    }