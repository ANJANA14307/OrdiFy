from typing import Any


def clean(value: Any) -> str:
    if value is None:
        return ""

    return str(value).strip()


def build_product_description_prompt(
    product_name: str,
    category: str | None,
    price: str | None,
    features: str | None,
    audience: str | None,
) -> str:
    return f"""
Create a clear and attractive product description.

Product name: {clean(product_name)}
Category: {clean(category) or "Not provided"}
Price: {clean(price) or "Not provided"}
Features: {clean(features) or "Not provided"}
Target customer: {clean(audience) or "General customers"}

Return:
1. A short product description
2. Three key selling points
3. A one-line version for product cards
"""


def build_instagram_caption_prompt(
    product_name: str,
    offer: str | None,
    audience: str | None,
    tone: str | None,
) -> str:
    return f"""
Write an Instagram sales caption.

Product: {clean(product_name)}
Offer: {clean(offer) or "No special offer"}
Audience: {clean(audience) or "General Instagram shoppers"}
Tone: {clean(tone) or "Friendly and modern"}

Include:
- One engaging caption
- A clear call to action
- 8 relevant hashtags
- Keep it natural and not too long
"""


def build_customer_reply_prompt(
    customer_message: str,
    product_context: str | None,
    reply_tone: str | None,
) -> str:
    return f"""
Write a helpful reply to a customer.

Customer message:
{clean(customer_message)}

Product or business context:
{clean(product_context) or "No additional context"}

Tone:
{clean(reply_tone) or "Friendly and professional"}

Return only the reply that can be sent directly to the customer.
Do not invent stock, price, delivery date, or product details.
"""


def build_sales_analysis_prompt(
    summary: str,
) -> str:
    return f"""
Explain this business performance in simple language:

{clean(summary)}

Return:
- What is going well
- What needs attention
- Three practical next steps
"""


def build_inventory_advice_prompt(
    inventory_summary: str,
) -> str:
    return f"""
Review this inventory information:

{clean(inventory_summary)}

Return:
- Products that may need restocking
- Products that may need promotion
- Simple actions the seller can take
Do not invent missing numbers.
"""


def build_general_chat_prompt(
    question: str,
    business_context: str | None,
) -> str:
    return f"""
Business context:
{clean(business_context) or "No business context provided"}

Question:
{clean(question)}

Answer as OrdiAI, a practical assistant for an Instagram seller.
"""