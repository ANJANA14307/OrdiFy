from fastapi import HTTPException, UploadFile
import cloudinary
import cloudinary.uploader

from core.config import settings


ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
}


def configure_cloudinary() -> None:
    missing = []

    if not settings.CLOUDINARY_CLOUD_NAME:
        missing.append("CLOUDINARY_CLOUD_NAME")

    if not settings.CLOUDINARY_API_KEY:
        missing.append("CLOUDINARY_API_KEY")

    if not settings.CLOUDINARY_API_SECRET:
        missing.append("CLOUDINARY_API_SECRET")

    if missing:
        raise HTTPException(
            status_code=503,
            detail=f"Cloudinary is not configured. Missing: {', '.join(missing)}",
        )

    cloudinary.config(
        cloud_name=settings.CLOUDINARY_CLOUD_NAME,
        api_key=settings.CLOUDINARY_API_KEY,
        api_secret=settings.CLOUDINARY_API_SECRET,
        secure=True,
    )


async def upload_product_image(file: UploadFile, user_id: str) -> dict:
    configure_cloudinary()

    if not file.content_type or file.content_type.lower() not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, PNG, and WEBP image files are allowed",
        )

    try:
        upload_result = cloudinary.uploader.upload(
            file.file,
            folder=f"ordify/products/{user_id}",
            resource_type="image",
            overwrite=False,
            unique_filename=True,
            use_filename=True,
        )

        secure_url = upload_result.get("secure_url")
        public_id = upload_result.get("public_id")

        if not secure_url or not public_id:
            raise HTTPException(
                status_code=500,
                detail="Cloudinary upload did not return image details",
            )

        return {
            "secure_url": secure_url,
            "public_id": public_id,
        }

    except HTTPException:
        raise

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Image upload failed: {str(exc)}",
        )