CREATE TABLE IF NOT EXISTS public.return_policies (
    business_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    return_window_days integer NOT NULL CHECK (return_window_days BETWEEN 1 AND 365),
    eligible_conditions text[] NOT NULL DEFAULT '{}',
    non_returnable_product_ids uuid[] NOT NULL DEFAULT '{}',
    allow_refund boolean NOT NULL DEFAULT true,
    allow_exchange boolean NOT NULL DEFAULT true,
    policy_text text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.return_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
    status text NOT NULL CHECK (status IN (
        'return_requested',
        'approved',
        'item_received',
        'inspected',
        'refund_issued',
        'exchange_created',
        'rejected'
    )),
    items jsonb NOT NULL,
    reason text NOT NULL,
    comment text,
    photos jsonb NOT NULL DEFAULT '[]'::jsonb,
    preferred_outcome text NOT NULL CHECK (preferred_outcome IN ('refund', 'exchange')),
    inspection_result text CHECK (
        inspection_result IS NULL OR inspection_result IN
            ('accepted', 'partially_accepted', 'rejected')
    ),
    inspection_notes text,
    inspection_photos jsonb NOT NULL DEFAULT '[]'::jsonb,
    inspected_at timestamptz,
    refund_amount numeric(12, 2),
    refund_reference text,
    exchange_order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
    rejection_reason text,
    messages jsonb NOT NULL DEFAULT '[]'::jsonb,
    requested_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT return_requests_refund_nonnegative CHECK (
        refund_amount IS NULL OR refund_amount >= 0
    )
);

CREATE INDEX IF NOT EXISTS return_requests_business_status_created_idx
    ON public.return_requests (business_id, status, requested_at DESC);
CREATE INDEX IF NOT EXISTS return_requests_order_idx
    ON public.return_requests (business_id, order_id);
CREATE UNIQUE INDEX IF NOT EXISTS return_requests_exchange_order_unique
    ON public.return_requests (exchange_order_id)
    WHERE exchange_order_id IS NOT NULL;

ALTER TABLE public.return_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.return_requests ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.create_return_request(
    p_business_id uuid,
    p_order_id uuid,
    p_items jsonb,
    p_reason text,
    p_comment text,
    p_photos jsonb,
    p_preferred_outcome text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    v_order public.orders%ROWTYPE;
    v_policy public.return_policies%ROWTYPE;
    v_input_item jsonb;
    v_order_item public.order_items%ROWTYPE;
    v_product public.products%ROWTYPE;
    v_remaining integer;
    v_requested integer;
    v_used integer;
    v_items jsonb := '[]'::jsonb;
    v_return public.return_requests%ROWTYPE;
BEGIN
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id AND user_id = p_business_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;
    IF v_order.status <> 'delivered' THEN
        RAISE EXCEPTION 'Return status conflict: order is not delivered';
    END IF;

    SELECT * INTO v_policy
    FROM public.return_policies
    WHERE business_id = p_business_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Return policy is not configured';
    END IF;
    IF v_order.updated_at < now() - make_interval(days => v_policy.return_window_days) THEN
        RAISE EXCEPTION 'Return window has expired';
    END IF;
    IF (p_preferred_outcome = 'refund' AND NOT v_policy.allow_refund)
        OR (p_preferred_outcome = 'exchange' AND NOT v_policy.allow_exchange) THEN
        RAISE EXCEPTION 'Preferred return outcome is disabled by policy';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'Return items must be an array';
    END IF;
    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'At least one return item is required';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM public.return_requests
        WHERE business_id = p_business_id
            AND order_id = p_order_id
            AND status IN ('return_requested', 'approved', 'item_received', 'inspected')
    ) THEN
        RAISE EXCEPTION 'Return status conflict: an open return already exists';
    END IF;

    FOR v_input_item IN
        SELECT input_item
        FROM jsonb_array_elements(p_items) AS request_items(input_item)
    LOOP
        SELECT * INTO v_order_item
        FROM public.order_items
        WHERE id = (v_input_item->>'order_item_id')::uuid
            AND order_id = p_order_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Return item does not belong to this order';
        END IF;

        v_requested := (v_input_item->>'quantity')::integer;
        IF v_requested IS NULL OR v_requested < 1 THEN
            RAISE EXCEPTION 'Return quantity must be positive';
        END IF;

        SELECT * INTO v_product
        FROM public.products
        WHERE id = v_order_item.product_id
            AND user_id = p_business_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Return item product is not owned by this business';
        END IF;
        IF v_order_item.product_id = ANY(v_policy.non_returnable_product_ids) THEN
            RAISE EXCEPTION 'This product is not returnable';
        END IF;

        SELECT COALESCE(sum(
            CASE
                WHEN returned_item ? 'accepted_quantity'
                    AND returned_item->>'accepted_quantity' IS NOT NULL
                    THEN (returned_item->>'accepted_quantity')::integer
                ELSE (returned_item->>'quantity')::integer
            END
        ), 0)
        INTO v_used
        FROM public.return_requests AS existing
        CROSS JOIN LATERAL jsonb_array_elements(existing.items)
            AS returned_items(returned_item)
        WHERE existing.business_id = p_business_id
            AND existing.order_id = p_order_id
            AND existing.status <> 'rejected'
            AND returned_items.returned_item->>'order_item_id' = v_order_item.id::text;

        v_remaining := v_order_item.quantity - v_used;
        IF v_requested > v_remaining THEN
            RAISE EXCEPTION 'Return quantity exceeds the remaining eligible quantity';
        END IF;

        v_items := v_items || jsonb_build_array(
            jsonb_build_object(
                'order_item_id', v_order_item.id,
                'product_id', v_order_item.product_id,
                'product_name', v_product.name,
                'variant_code', COALESCE(v_order_item.variant_notes, ''),
                'unit_price', v_order_item.unit_price,
                'quantity', v_requested,
                'accepted_quantity', NULL
            )
        );
    END LOOP;

    INSERT INTO public.return_requests (
        business_id,
        order_id,
        customer_id,
        status,
        items,
        reason,
        comment,
        photos,
        preferred_outcome,
        messages
    )
    VALUES (
        p_business_id,
        p_order_id,
        v_order.customer_id,
        'return_requested',
        v_items,
        p_reason,
        p_comment,
        COALESCE(p_photos, '[]'::jsonb),
        p_preferred_outcome,
        jsonb_build_array(
            jsonb_build_object(
                'status', 'return_requested',
                'message', 'Return requested',
                'at', now()
            )
        )
    )
    RETURNING * INTO v_return;

    RETURN to_jsonb(v_return);
END;
$$;

REVOKE ALL ON FUNCTION public.create_return_request(
    uuid, uuid, jsonb, text, text, jsonb, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_return_request(
    uuid, uuid, jsonb, text, text, jsonb, text
) TO service_role;

CREATE OR REPLACE FUNCTION public.inspect_return_request(
    p_return_id uuid,
    p_business_id uuid,
    p_inspection_result text,
    p_inspected_items jsonb,
    p_notes text,
    p_photos jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    v_return public.return_requests%ROWTYPE;
    v_item jsonb;
    v_order_item jsonb;
    v_requested integer;
    v_accepted integer;
    v_total_requested integer := 0;
    v_total_accepted integer := 0;
    v_product_id uuid;
    v_variant_code text;
    v_variant_id uuid;
    v_stock integer;
    v_result_status text;
BEGIN
    SELECT * INTO v_return
    FROM public.return_requests
    WHERE id = p_return_id AND business_id = p_business_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Return request not found';
    END IF;
    IF v_return.status <> 'item_received' THEN
        RAISE EXCEPTION 'Return status conflict: inspection requires item_received';
    END IF;
    IF p_inspection_result IS NULL
        OR p_inspection_result NOT IN ('accepted', 'partially_accepted', 'rejected') THEN
        RAISE EXCEPTION 'Invalid inspection result';
    END IF;
    IF p_inspected_items IS NULL
        OR jsonb_typeof(p_inspected_items) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'Inspection items must be an array';
    END IF;

    FOR v_item IN
        SELECT return_item
        FROM jsonb_array_elements(v_return.items) AS return_items(return_item)
    LOOP
        v_order_item := NULL;
        SELECT inspected_item INTO v_order_item
        FROM jsonb_array_elements(p_inspected_items) AS inspected_items(inspected_item)
        WHERE inspected_item->>'order_item_id' = v_item->>'order_item_id'
        LIMIT 1;
        IF v_order_item IS NULL THEN
            RAISE EXCEPTION 'Inspection quantity missing for return item';
        END IF;
        v_requested := (v_item->>'quantity')::integer;
        v_accepted := (v_order_item->>'accepted_quantity')::integer;
        IF v_accepted IS NULL OR v_requested IS NULL
            OR v_accepted < 0 OR v_accepted > v_requested THEN
            RAISE EXCEPTION 'Accepted quantity must be between zero and requested quantity';
        END IF;
        v_total_requested := v_total_requested + v_requested;
        v_total_accepted := v_total_accepted + v_accepted;
    END LOOP;

    IF jsonb_array_length(p_inspected_items) <> jsonb_array_length(v_return.items) THEN
        RAISE EXCEPTION 'Inspection item list does not match the return request';
    END IF;
    IF p_inspection_result = 'accepted' AND v_total_accepted <> v_total_requested THEN
        RAISE EXCEPTION 'All requested items must be accepted for an accepted inspection';
    END IF;
    IF p_inspection_result = 'partially_accepted'
        AND (v_total_accepted = 0 OR v_total_accepted = v_total_requested) THEN
        RAISE EXCEPTION 'Partial inspection must accept some, but not all, items';
    END IF;
    IF p_inspection_result = 'rejected' AND v_total_accepted <> 0 THEN
        RAISE EXCEPTION 'Rejected inspection cannot accept any item quantity';
    END IF;

    FOR v_item IN
        SELECT return_item
        FROM jsonb_array_elements(v_return.items) AS return_items(return_item)
    LOOP
        SELECT inspected_item INTO v_order_item
        FROM jsonb_array_elements(p_inspected_items) AS inspected_items(inspected_item)
        WHERE inspected_item->>'order_item_id' = v_item->>'order_item_id'
        LIMIT 1;
        v_accepted := (v_order_item->>'accepted_quantity')::integer;
        IF v_accepted = 0 THEN
            CONTINUE;
        END IF;

        v_product_id := (v_item->>'product_id')::uuid;
        v_variant_code := NULLIF(v_item->>'variant_code', '');
        IF v_variant_code IS NOT NULL THEN
            SELECT id, stock INTO v_variant_id, v_stock
            FROM public.product_variants
            WHERE business_id = p_business_id
                AND product_id = v_product_id
                AND code = v_variant_code
            FOR UPDATE;
            IF FOUND THEN
                UPDATE public.product_variants
                SET stock = v_stock + v_accepted,
                    updated_at = now()
                WHERE id = v_variant_id AND business_id = p_business_id;
                CONTINUE;
            END IF;
            RAISE EXCEPTION 'Return variant is no longer available for stock restoration';
        END IF;

        UPDATE public.products
        SET stock_count = COALESCE(stock_count, 0) + v_accepted
        WHERE id = v_product_id AND user_id = p_business_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Return item product is not owned by this business';
        END IF;
    END LOOP;

    v_result_status := CASE
        WHEN p_inspection_result = 'rejected' THEN 'rejected'
        ELSE 'inspected'
    END;

    UPDATE public.return_requests
    SET items = (
            SELECT jsonb_agg(updated_item)
            FROM (
                SELECT jsonb_set(
                    item,
                    '{accepted_quantity}',
                    to_jsonb((inspected->>'accepted_quantity')::integer),
                    true
                ) AS updated_item
                FROM jsonb_array_elements(v_return.items) AS return_items(item)
                JOIN jsonb_array_elements(p_inspected_items)
                    AS inspected_items(inspected)
                    ON return_items.item->>'order_item_id'
                        = inspected_items.inspected->>'order_item_id'
            ) AS accepted_items
        ),
        status = v_result_status,
        inspection_result = p_inspection_result,
        inspection_notes = p_notes,
        inspection_photos = COALESCE(p_photos, '[]'::jsonb),
        inspected_at = now(),
        updated_at = now()
    WHERE id = p_return_id AND business_id = p_business_id
    RETURNING * INTO v_return;

    RETURN to_jsonb(v_return);
END;
$$;

REVOKE ALL ON FUNCTION public.inspect_return_request(
    uuid, uuid, text, jsonb, text, jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.inspect_return_request(
    uuid, uuid, text, jsonb, text, jsonb
) TO service_role;

CREATE OR REPLACE FUNCTION public.create_return_exchange(
    p_return_id uuid,
    p_business_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    v_return public.return_requests%ROWTYPE;
    v_order_id uuid;
    v_item jsonb;
BEGIN
    SELECT * INTO v_return
    FROM public.return_requests
    WHERE id = p_return_id AND business_id = p_business_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Return request not found';
    END IF;
    IF v_return.status <> 'inspected' THEN
        RAISE EXCEPTION 'Return status conflict: exchange requires inspection';
    END IF;
    IF v_return.inspection_result = 'rejected' THEN
        RAISE EXCEPTION 'Rejected items cannot be exchanged';
    END IF;
    IF v_return.exchange_order_id IS NOT NULL THEN
        RAISE EXCEPTION 'Exchange order already exists';
    END IF;

    INSERT INTO public.orders (
        user_id,
        customer_id,
        status,
        source,
        notes,
        subtotal,
        delivery_fee,
        tax_amount,
        discount_amount,
        total_amount
    )
    VALUES (
        p_business_id,
        v_return.customer_id,
        'new',
        'manual',
        'Exchange for return ' || p_return_id::text,
        0,
        0,
        0,
        0,
        0
    )
    RETURNING id INTO v_order_id;

    FOR v_item IN
        SELECT return_item
        FROM jsonb_array_elements(v_return.items) AS return_items(return_item)
    LOOP
        IF COALESCE((v_item->>'accepted_quantity')::integer, 0) <= 0 THEN
            CONTINUE;
        END IF;

        INSERT INTO public.order_items (
            order_id,
            product_id,
            quantity,
            unit_price,
            variant_notes
        )
        VALUES (
            v_order_id,
            (v_item->>'product_id')::uuid,
            (v_item->>'accepted_quantity')::integer,
            COALESCE((v_item->>'unit_price')::numeric, 0),
            NULLIF(v_item->>'variant_code', '')
        );
    END LOOP;

    UPDATE public.orders
    SET order_number = 'ORD-' || upper(substr(replace(v_order_id::text, '-', ''), 1, 8))
    WHERE id = v_order_id AND user_id = p_business_id;

    UPDATE public.return_requests
    SET status = 'exchange_created',
        exchange_order_id = v_order_id,
        messages = messages || jsonb_build_array(
            jsonb_build_object(
                'status', 'exchange_created',
                'message', 'Exchange order created',
                'at', now()
            )
        ),
        updated_at = now()
    WHERE id = p_return_id AND business_id = p_business_id
    RETURNING * INTO v_return;

    RETURN jsonb_build_object(
        'return_request', to_jsonb(v_return),
        'exchange_order_id', v_order_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.create_return_exchange(uuid, uuid)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_return_exchange(uuid, uuid)
    TO service_role;
