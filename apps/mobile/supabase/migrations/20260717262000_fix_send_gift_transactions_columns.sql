-- Fix: send_gift / agency payout used wrong transactions columns
-- (currency, type) instead of (currency_type, transaction_type).

CREATE OR REPLACE FUNCTION public.send_gift_tx_columns_noop()
RETURNS void
LANGUAGE sql
AS $$ SELECT NULL; $$;

DROP FUNCTION IF EXISTS public.send_gift_tx_columns_noop();

-- Live DB was patched by replacing function bodies; keep this migration as
-- documentation + safety re-apply for send_gift transaction insert shape.

DO $$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'send_gift'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE NOTICE 'send_gift not found';
    RETURN;
  END IF;

  IF v_def LIKE '%currency, type%' OR v_def LIKE '%(user_id, amount, currency, type,%' THEN
    v_def := replace(
      v_def,
      'INSERT INTO public.transactions (user_id, amount, currency, type, reference_id)',
      'INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)'
    );
    EXECUTE v_def;
    RAISE NOTICE 'send_gift patched for currency_type/transaction_type';
  ELSE
    RAISE NOTICE 'send_gift already uses currency_type';
  END IF;
END $$;
