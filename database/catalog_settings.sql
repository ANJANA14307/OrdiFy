CREATE TABLE IF NOT EXISTS public.catalog_settings (
    business_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    slug text NOT NULL UNIQUE,
    is_public boolean NOT NULL DEFAULT false,
    selected_product_ids uuid[] NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS catalog_settings_public_slug_idx
    ON public.catalog_settings (slug)
    WHERE is_public = true;

ALTER TABLE public.catalog_settings ENABLE ROW LEVEL SECURITY;
