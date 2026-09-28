-- Batch daily gift totals for room cards (Popular / New / Room tab).

CREATE OR REPLACE FUNCTION public.get_rooms_daily_gift_totals(p_room_ids uuid[])
RETURNS TABLE (
  room_id uuid,
  total bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    gl.room_id,
    COALESCE(SUM(gl.amount), 0)::bigint AS total
  FROM public.gift_logs gl
  WHERE gl.room_id = ANY (p_room_ids)
    AND gl.created_at >= date_trunc('day', now())
  GROUP BY gl.room_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_rooms_daily_gift_totals(uuid[])
  TO anon, authenticated, service_role;
