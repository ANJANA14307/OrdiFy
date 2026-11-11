CREATE TABLE IF NOT EXISTS public.whatsapp_order_settings (
    business_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    phone_number text,
    phone_number_id text UNIQUE,
    is_enabled boolean NOT NULL DEFAULT false,
    templates jsonb NOT NULL DEFAULT
        '{"confirmation":"Hi {name}, we received your order {order_id}. Total: ₹{total}. Reply CONFIRM {order_id} to place it.","shipped":"Hi {name}, order {order_id} has shipped. Total: ₹{total}.","delivered":"Hi {name}, order {order_id} has been delivered. Total: ₹{total}."}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.whatsapp_social_orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    source_message_id text NOT NULL UNIQUE,
    confirmation_message_id text UNIQUE,
    confirmation_code text NOT NULL UNIQUE,
    customer_phone text NOT NULL,
    customer_name text,
    product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
    variant_id uuid REFERENCES public.product_variants(id) ON DELETE SET NULL,
    product_code text,
    quantity integer CHECK (quantity > 0),
    delivery_pincode text,
    shipping_address text,
    payment_method text,
    status text NOT NULL CHECK (status IN (
        'awaiting_customer_confirmation',
        'confirmation_failed',
        'confirmation_processing',
        'confirmed',
        'failed_validation',
        'out_of_stock',
        'rejected',
        'edit_requested'
    )),
    validation_result jsonb NOT NULL DEFAULT '{}'::jsonb,
    subtotal numeric(12, 2) NOT NULL DEFAULT 0,
    delivery_fee numeric(12, 2) NOT NULL DEFAULT 0,
    tax_amount numeric(12, 2) NOT NULL DEFAULT 0,
    discount_amount numeric(12, 2) NOT NULL DEFAULT 0,
    total_amount numeric(12, 2) NOT NULL DEFAULT 0,
    messages jsonb NOT NULL DEFAULT '[]'::jsonb,
    order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
    customer_confirmed_at timestamptz,
    business_confirmed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS whatsapp_social_orders_business_created_idx
    ON public.whatsapp_social_orders (business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS whatsapp_social_orders_business_status_idx
    ON public.whatsapp_social_orders (business_id, status);
CREATE INDEX IF NOT EXISTS whatsapp_social_orders_customer_confirmation_idx
    ON public.whatsapp_social_orders
        (business_id, customer_phone, confirmation_code, status);

ALTER TABLE public.whatsapp_order_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_social_orders ENABLE ROW LEVEL SECURITY;
