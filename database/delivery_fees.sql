CREATE TABLE IF NOT EXISTS public.delivery_settings (
    business_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    rule_type text NOT NULL CHECK (
        rule_type IN ('flat_fee', 'free_above_minimum', 'pincode_zone')
    ),
    flat_fee numeric(12, 2) NOT NULL DEFAULT 0 CHECK (flat_fee >= 0),
    free_delivery_threshold numeric(12, 2)
        CHECK (free_delivery_threshold IS NULL OR free_delivery_threshold >= 0),
    zones jsonb NOT NULL DEFAULT '[]'::jsonb,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (
        rule_type <> 'free_above_minimum'
        OR free_delivery_threshold IS NOT NULL
    )
);

ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS subtotal numeric(12, 2),
    ADD COLUMN IF NOT EXISTS delivery_fee numeric(12, 2),
    ADD COLUMN IF NOT EXISTS tax_amount numeric(12, 2),
    ADD COLUMN IF NOT EXISTS discount_amount numeric(12, 2),
    ADD COLUMN IF NOT EXISTS delivery_pincode text;

UPDATE public.orders
SET subtotal = COALESCE(subtotal, total_amount, 0),
    delivery_fee = COALESCE(delivery_fee, 0),
    tax_amount = COALESCE(tax_amount, 0),
    discount_amount = COALESCE(discount_amount, 0)
WHERE subtotal IS NULL
   OR delivery_fee IS NULL
   OR tax_amount IS NULL
   OR discount_amount IS NULL;

ALTER TABLE public.orders
    ALTER COLUMN subtotal SET DEFAULT 0,
    ALTER COLUMN delivery_fee SET DEFAULT 0,
    ALTER COLUMN tax_amount SET DEFAULT 0,
    ALTER COLUMN discount_amount SET DEFAULT 0;
