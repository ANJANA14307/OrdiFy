ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS instagram_user_id text,
    ADD COLUMN IF NOT EXISTS instagram_username text,
    ADD COLUMN IF NOT EXISTS instagram_connected_at timestamptz;

CREATE TABLE IF NOT EXISTS public.instagram_redirect_settings (
    business_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_enabled boolean NOT NULL DEFAULT false,
    trigger_keywords text[] NOT NULL DEFAULT ARRAY['price', 'order'],
    reply_text text NOT NULL DEFAULT
        'Thanks for reaching out! Browse the catalog: {catalog_link}' || E'\n' ||
        'To order, message us on WhatsApp: {whatsapp_link}',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT instagram_reply_contains_redirects CHECK (
        position('{catalog_link}' in reply_text) > 0
        AND position('{whatsapp_link}' in reply_text) > 0
    )
);

CREATE TABLE IF NOT EXISTS public.instagram_redirect_clicks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    catalog_slug text NOT NULL,
    destination text NOT NULL CHECK (destination IN ('catalog', 'whatsapp', 'product')),
    tracking_tag text NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS instagram_redirect_clicks_business_created_idx
    ON public.instagram_redirect_clicks (business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS instagram_redirect_clicks_business_tag_idx
    ON public.instagram_redirect_clicks (business_id, tracking_tag);

CREATE TABLE IF NOT EXISTS public.instagram_auto_reply_events (
    message_id text NOT NULL,
    business_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reply_text text,
    reply_error text,
    created_at timestamptz NOT NULL DEFAULT now(),
    replied_at timestamptz,
    PRIMARY KEY (business_id, message_id)
);

CREATE INDEX IF NOT EXISTS instagram_auto_reply_events_business_created_idx
    ON public.instagram_auto_reply_events (business_id, created_at DESC);

ALTER TABLE public.instagram_redirect_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.instagram_redirect_clicks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.instagram_auto_reply_events ENABLE ROW LEVEL SECURITY;
