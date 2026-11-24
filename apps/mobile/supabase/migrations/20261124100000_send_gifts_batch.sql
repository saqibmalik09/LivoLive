-- One round-trip multi-receiver gift settle for gateway storms (10–100k rooms).
-- Reuses public.send_gift so ledger rules stay identical; callers get one JSON
-- array instead of N sequential client→DB hops.

CREATE OR REPLACE FUNCTION public.send_gifts_batch(
  p_sender_id uuid,
  p_receiver_ids uuid[],
  p_gift_id uuid,
  p_room_id uuid,
  p_quantity integer,
  p_lucky_engine text DEFAULT 'gateway'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_recv uuid;
  v_one json;
  v_results jsonb := '[]'::jsonb;
  v_seen uuid[] := ARRAY[]::uuid[];
  v_qty int := GREATEST(1, COALESCE(p_quantity, 1));
BEGIN
  IF p_sender_id IS NULL OR p_gift_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'sender and gift required',
      'results', '[]'::jsonb
    );
  END IF;

  IF p_receiver_ids IS NULL OR cardinality(p_receiver_ids) = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No receivers',
      'results', '[]'::jsonb
    );
  END IF;

  FOREACH v_recv IN ARRAY p_receiver_ids LOOP
    IF v_recv IS NULL THEN
      CONTINUE;
    END IF;
    IF v_recv = ANY (v_seen) THEN
      CONTINUE;
    END IF;
    v_seen := array_append(v_seen, v_recv);

    BEGIN
      v_one := public.send_gift(
        p_sender_id,
        v_recv,
        p_gift_id,
        p_room_id,
        v_qty,
        p_lucky_engine
      );
    EXCEPTION WHEN OTHERS THEN
      v_one := json_build_object(
        'success', false,
        'message', SQLERRM
      );
    END;

    v_results := v_results || jsonb_build_array(
      jsonb_build_object(
        'receiver_id', v_recv,
        'result', COALESCE(v_one::jsonb, '{}'::jsonb)
      )
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success', EXISTS (
      SELECT 1
      FROM jsonb_array_elements(v_results) AS e
      WHERE COALESCE((e->'result'->>'success')::boolean, false)
    ),
    'results', v_results
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.send_gifts_batch(uuid, uuid[], uuid, uuid, integer, text)
  TO authenticated, service_role;
