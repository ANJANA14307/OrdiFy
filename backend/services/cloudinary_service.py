from fastapi import UploadFile, HTTPException
import cloudinary
import cloudinary.uploader

from core.config import settings


def configure_cloudinary():
    if not settings.CLOUDINARY_CLOUD_NAME:
        raise HTTPException(
            status_code=500,
            detail="Cloudinary cloud name is not configured"
        )

    if not settings.CLOUDINARY_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="Cloudinary API key is not configured"
        )

    if not settings.CLOUDINARY_API_SECRET:
        raise HTTPException(
            status_code=500,
            detail="Cloudinary API secret is not configured"
        )

    cloudinary.config(
        cloud_name=settings.CLOUDINARY_CLOUD_NAME,
        api_key=settings.CLOUDINARY_API_KEY,
        api_secret=settings.CLOUDINARY_API_SECRET,
        secure=True
    )


async def upload_product_image(file: UploadFile, user_id: str):
    configure_cloudinary()

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="Only image files are allowed"
        )

    try:
        upload_result = cloudinary.uploader.upload(
            file.file,
            folder=f"ordify/products/{user_id}",
            resource_type="image"
        )

        return {
            "secure_url": upload_result.get("secure_url"),
            "public_id": upload_result.get("public_id")
        }

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Image upload failed: {str(exc)}"
        )