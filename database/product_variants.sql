CREATE TABLE IF NOT EXISTS public.product_variants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    business_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    code text NOT NULL CHECK (code ~ '^[A-Z0-9]+(-[A-Z0-9]+)*$'),
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    price numeric(12, 2) NOT NULL CHECK (price > 0),
    stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_variants_business_code_unique UNIQUE (business_id, code)
);

CREATE INDEX IF NOT EXISTS product_variants_product_business_idx
    ON public.product_variants (product_id, business_id);
