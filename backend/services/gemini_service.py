from google import genai
from fastapi import HTTPException

from core.config import settings


SYSTEM_PROMPT = """
You are OrdiAI, the smart business assistant inside OrdiFY.

OrdiFY helps Instagram sellers and small businesses manage:
- products
- inventory
- customers
- orders
- payments
- invoices
- Instagram content
- customer replies

Rules:
- Use simple, easy-to-understand English.
- Avoid complicated business jargon.
- Be practical and helpful.
- Keep responses concise.
- Use short paragraphs or bullet points when useful.
- Never invent product prices, stock levels, customer details, or sales data.
"""


def get_gemini_client():
    if not settings.GEMINI_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="Gemini is not configured. Add GEMINI_API_KEY in backend .env.",
        )

    return genai.Client(api_key=settings.GEMINI_API_KEY)


def generate_ai_text(
    user_prompt: str,
    max_words: int = 220,
) -> str:
    cleaned_prompt = user_prompt.strip()

    if not cleaned_prompt:
        raise HTTPException(
            status_code=400,
            detail="AI prompt cannot be empty",
        )

    client = get_gemini_client()

    final_prompt = f"""
{SYSTEM_PROMPT}

Keep the answer under approximately {max_words} words.

User request:
{cleaned_prompt}
"""

    try:
        response = client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=final_prompt,
        )
    except Exception as error:
        raise HTTPException(
            status_code=502,
            detail=f"Gemini request failed: {str(error)}",
        )

    text = getattr(response, "text", None)

    if not text or not text.strip():
        raise HTTPException(
            status_code=502,
            detail="Gemini returned an empty response",
        )

    return text.strip()