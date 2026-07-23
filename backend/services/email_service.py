from typing import Any

import httpx
from fastapi import HTTPException

from core.config import settings


def send_email_via_resend(
    to_email: str,
    subject: str,
    html: str,
    text: str | None = None,
    idempotency_key: str | None = None,
):
    if not settings.RESEND_API_KEY:
        raise HTTPException(
            status_code=400,
            detail="Resend API key is missing. Add RESEND_API_KEY in backend .env.",
        )

    if not settings.EMAIL_FROM:
        raise HTTPException(
            status_code=400,
            detail="EMAIL_FROM is missing in backend .env.",
        )

    if not to_email or not to_email.strip():
        raise HTTPException(
            status_code=400,
            detail="Recipient email is required.",
        )

    payload: dict[str, Any] = {
        "from": settings.EMAIL_FROM,
        "to": [to_email.strip()],
        "subject": subject,
        "html": html,
    }

    if text:
        payload["text"] = text

    headers = {
        "Authorization": f"Bearer {settings.RESEND_API_KEY}",
        "Content-Type": "application/json",
    }

    if idempotency_key:
        headers["Idempotency-Key"] = idempotency_key[:256]

    response = httpx.post(
        "https://api.resend.com/emails",
        headers=headers,
        json=payload,
        timeout=30,
    )

    try:
        response_json = response.json()
    except Exception:
        response_json = {
            "raw": response.text,
        }

    if response.status_code not in [200, 201, 202]:
        raise HTTPException(
            status_code=502,
            detail={
                "message": "Resend email send failed",
                "status_code": response.status_code,
                "response": response_json,
            },
        )

    return {
        "provider": "resend",
        "status_code": response.status_code,
        "response": response_json,
    }