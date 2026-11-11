CREATE TABLE IF NOT EXISTS public.catalog_products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 160),
    brand text,
    category text NOT NULL CHECK (length(trim(category)) BETWEEN 1 AND 100),
    description text,
    images jsonb NOT NULL DEFAULT '[]'::jsonb,
    status text NOT NULL DEFAULT 'approved'
        CHECK (status IN ('pending_review', 'approved', 'rejected')),
    submitted_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    review_notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS catalog_products_approved_search_idx
    ON public.catalog_products (status, lower(name), lower(category));

CREATE TABLE IF NOT EXISTS public.business_listings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    catalog_product_id uuid NOT NULL REFERENCES public.catalog_products(id) ON DELETE RESTRICT,
    price numeric(12, 2) NOT NULL CHECK (price > 0),
    stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
    is_active boolean NOT NULL DEFAULT true,
    delivery_override jsonb,
    return_policy_override jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT business_listings_one_product_per_business
        UNIQUE (business_id, catalog_product_id)
);

CREATE INDEX IF NOT EXISTS business_listings_business_active_idx
    ON public.business_listings (business_id, is_active, created_at DESC);

CREATE TABLE IF NOT EXISTS public.business_listing_variants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id uuid NOT NULL REFERENCES public.business_listings(id) ON DELETE CASCADE,
    business_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    code text NOT NULL CHECK (code ~ '^[A-Z0-9]+(-[A-Z0-9]+)*$'),
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    price numeric(12, 2) NOT NULL CHECK (price > 0),
    stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT business_listing_variant_business_code_unique UNIQUE (business_id, code)
);

CREATE INDEX IF NOT EXISTS business_listing_variants_listing_business_idx
    ON public.business_listing_variants (listing_id, business_id);

CREATE TABLE IF NOT EXISTS public.product_catalog_mappings (
    product_id uuid PRIMARY KEY REFERENCES public.products(id) ON DELETE CASCADE,
    business_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    catalog_product_id uuid NOT NULL REFERENCES public.catalog_products(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_catalog_mappings_business_product_unique
        UNIQUE (business_id, product_id)
);

ALTER TABLE public.catalog_settings
    ADD COLUMN IF NOT EXISTS selected_listing_ids uuid[] NOT NULL DEFAULT '{}';

ALTER TABLE public.catalog_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_listing_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_catalog_mappings ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.create_business_listing(
    p_business_id uuid,
    p_catalog_product_id uuid,
    p_price numeric,
    p_stock integer,
    p_variants jsonb,
    p_delivery_override jsonb,
    p_return_policy_override jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    v_listing public.business_listings%ROWTYPE;
    v_variant jsonb;
    v_code text;
BEGIN
    IF p_price <= 0 OR p_stock < 0 THEN
        RAISE EXCEPTION 'Listing price must be positive and stock cannot be negative';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.catalog_products
        WHERE id = p_catalog_product_id AND status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Catalog product is not approved or available';
    END IF;
    IF p_variants IS NULL OR jsonb_typeof(p_variants) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'Listing variants must be an array';
    END IF;

    INSERT INTO public.business_listings (
        business_id, catalog_product_id, price, stock,
        delivery_override, return_policy_override
    )
    VALUES (
        p_business_id, p_catalog_product_id, p_price, p_stock,
        p_delivery_override, p_return_policy_override
    )
    RETURNING * INTO v_listing;

    FOR v_variant IN
        SELECT variant
        FROM jsonb_array_elements(p_variants) AS listing_variants(variant)
    LOOP
        v_code := v_variant->>'code';
        IF v_code IS NULL OR v_code !~ '^[A-Z0-9]+(-[A-Z0-9]+)*$' THEN
            RAISE EXCEPTION 'Variant code must use uppercase letters, numbers, and hyphens only';
        END IF;
        INSERT INTO public.business_listing_variants (
            listing_id, business_id, code, attributes, price, stock, is_active
        )
        VALUES (
            v_listing.id,
            p_business_id,
            v_code,
            COALESCE(v_variant->'attributes', '{}'::jsonb),
            COALESCE((v_variant->>'price')::numeric, p_price),
            COALESCE((v_variant->>'stock')::integer, 0),
            COALESCE((v_variant->>'is_active')::boolean, true)
        );
    END LOOP;

    RETURN to_jsonb(v_listing) || jsonb_build_object(
        'variants', COALESCE(
            (SELECT jsonb_agg(to_jsonb(variant))
             FROM public.business_listing_variants AS variant
             WHERE variant.listing_id = v_listing.id
                AND variant.business_id = p_business_id),
            '[]'::jsonb
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.create_business_listing(
    uuid, uuid, numeric, integer, jsonb, jsonb, jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_business_listing(
    uuid, uuid, numeric, integer, jsonb, jsonb, jsonb
) TO service_role;
