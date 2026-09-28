-- Profile gift aggregates: server-side SUM and grouped received gifts.
-- Optional index apply: sklive-scripts/apply_profile_gift_aggregates.js (CONCURRENTLY).

CREATE OR REPLACE FUNCTION public.user_total_sent(p_user uuid)
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(SUM(amount), 0)::bigint
  FROM public.gift_logs WHERE sender_id = p_user;
$$;

CREATE OR REPLACE FUNCTION public.user_received_gifts_summary(
  p_user uuid, p_limit int DEFAULT 10
)
RETURNS TABLE (id uuid, name text, image_url text, count bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT g.gift_id, si.name, si.image_url, COUNT(*)::bigint
  FROM public.gift_logs g
  JOIN public.shop_items si ON si.id = g.gift_id
  WHERE g.receiver_id = p_user
  GROUP BY g.gift_id, si.name, si.image_url
  ORDER BY COUNT(*) DESC
  LIMIT GREATEST(p_limit, 0);
$$;

CREATE INDEX IF NOT EXISTS gift_logs_sender_amount_idx
  ON public.gift_logs (sender_id) INCLUDE (amount);
