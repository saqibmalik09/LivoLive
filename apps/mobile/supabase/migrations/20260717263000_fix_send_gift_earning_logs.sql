-- Fix send_gift: earning_logs uses gift_log_id/host_id (not room_id/sender_id).
-- Insert gift_logs first, then earning_logs with the real schema.

DO $$
DECLARE
  v_def text;
  v_new text;
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

  IF v_def !~ 'earning_logs[\s\S]{0,120}room_id' THEN
    RAISE NOTICE 'send_gift earning_logs already correct';
    RETURN;
  END IF;

  v_new := regexp_replace(
    v_def,
    'INSERT INTO public\.earning_logs\s*\(\s*room_id[\s\S]*?RETURNING id INTO v_gift_log_id;',
    $fix$INSERT INTO public.gift_logs (sender_id, receiver_id, gift_id, room_id, amount)
  VALUES (p_sender_id, p_receiver_id, p_gift_id, p_room_id, v_total_cost)
  RETURNING id INTO v_gift_log_id;

  INSERT INTO public.earning_logs (
    gift_log_id, host_id, host_amount,
    agency_owner_id, agency_amount,
    bd_staff_id, bd_amount,
    bd_admin_staff_id, bd_admin_amount,
    super_bd_staff_id, super_bd_amount,
    official_amount, admin_amount,
    total_gift_value
  ) VALUES (
    v_gift_log_id, p_receiver_id, v_host_share,
    v_agency_owner_id, 0,
    NULL, 0,
    NULL, 0,
    NULL, 0,
    v_official_share, v_official_share,
    v_total_cost
  );$fix$
  );

  IF v_new = v_def THEN
    RAISE EXCEPTION 'Failed to patch send_gift earning_logs insert';
  END IF;

  EXECUTE v_new;
  RAISE NOTICE 'send_gift patched: gift_logs + earning_logs schema';
END $$;
