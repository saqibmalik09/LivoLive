-- Solo PK (1v1): timed gift battle between seat 0 and seat 1 users.

ALTER TABLE public.room_pk_sessions
  ADD COLUMN IF NOT EXISTS session_type text NOT NULL DEFAULT 'team'
    CHECK (session_type IN ('team', 'solo')),
  ADD COLUMN IF NOT EXISTS player_a_id uuid REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS player_b_id uuid REFERENCES public.users(id);

-- Ensure team PK sessions are tagged explicitly on start.
CREATE OR REPLACE FUNCTION public.start_room_pk_session(
  p_room_id uuid,
  p_duration_minutes integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_session_id uuid;
  v_ends_at timestamptz;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF NOT public.user_can_manage_room(p_room_id, v_user_id) THEN
    RETURN json_build_object('success', false, 'message', 'Not authorized');
  END IF;

  IF p_duration_minutes NOT IN (5, 15, 30) THEN
    RETURN json_build_object('success', false, 'message', 'Invalid duration');
  END IF;

  PERFORM public.sync_room_pk_session(p_room_id);

  IF EXISTS (
    SELECT 1 FROM public.room_pk_sessions
    WHERE room_id = p_room_id AND status = 'active'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'PK already active');
  END IF;

  v_ends_at := now() + (p_duration_minutes || ' minutes')::interval;

  INSERT INTO public.room_pk_sessions (
    room_id,
    started_by,
    duration_minutes,
    ends_at,
    session_type
  )
  VALUES (
    p_room_id,
    v_user_id,
    p_duration_minutes,
    v_ends_at,
    'team'
  )
  RETURNING id INTO v_session_id;

  UPDATE public.rooms
  SET mic_count = 10
  WHERE id = p_room_id;

  RETURN json_build_object(
    'success', true,
    'session_id', v_session_id,
    'ends_at', v_ends_at,
    'duration_minutes', p_duration_minutes,
    'session_type', 'team'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.start_room_solo_pk_session(
  p_room_id uuid,
  p_duration_minutes integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_session_id uuid;
  v_ends_at timestamptz;
  v_player_a_id uuid;
  v_player_b_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF NOT public.user_can_manage_room(p_room_id, v_user_id) THEN
    RETURN json_build_object('success', false, 'message', 'Not authorized');
  END IF;

  IF p_duration_minutes NOT IN (5, 15, 30) THEN
    RETURN json_build_object('success', false, 'message', 'Invalid duration');
  END IF;

  PERFORM public.sync_room_pk_session(p_room_id);

  IF EXISTS (
    SELECT 1 FROM public.room_pk_sessions
    WHERE room_id = p_room_id AND status = 'active'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'PK already active');
  END IF;

  SELECT rs.user_id INTO v_player_a_id
  FROM public.room_seats rs
  WHERE rs.room_id = p_room_id
    AND rs.seat_index = 0
    AND rs.user_id IS NOT NULL;

  IF v_player_a_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Both PK seats (1 & 2) must be occupied'
    );
  END IF;

  SELECT rs.user_id INTO v_player_b_id
  FROM public.room_seats rs
  WHERE rs.room_id = p_room_id
    AND rs.seat_index = 1
    AND rs.user_id IS NOT NULL;

  IF v_player_b_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Both PK seats (1 & 2) must be occupied'
    );
  END IF;

  v_ends_at := now() + (p_duration_minutes || ' minutes')::interval;

  INSERT INTO public.room_pk_sessions (
    room_id,
    started_by,
    duration_minutes,
    ends_at,
    session_type,
    player_a_id,
    player_b_id
  )
  VALUES (
    p_room_id,
    v_user_id,
    p_duration_minutes,
    v_ends_at,
    'solo',
    v_player_a_id,
    v_player_b_id
  )
  RETURNING id INTO v_session_id;

  RETURN json_build_object(
    'success', true,
    'session_id', v_session_id,
    'ends_at', v_ends_at,
    'duration_minutes', p_duration_minutes,
    'session_type', 'solo',
    'player_a_id', v_player_a_id,
    'player_b_id', v_player_b_id
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.attribute_pk_gift()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_session public.room_pk_sessions%ROWTYPE;
  v_seat_index integer;
  v_team text;
BEGIN
  IF NEW.room_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_session
  FROM public.room_pk_sessions
  WHERE room_id = NEW.room_id
    AND status = 'active'
    AND ends_at > now()
  ORDER BY started_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  IF v_session.session_type = 'solo' THEN
    IF NEW.receiver_id = v_session.player_a_id THEN
      v_team := 'a';
      v_seat_index := 0;
    ELSIF NEW.receiver_id = v_session.player_b_id THEN
      v_team := 'b';
      v_seat_index := 1;
    ELSE
      RETURN NEW;
    END IF;
  ELSE
    SELECT rs.seat_index INTO v_seat_index
    FROM public.room_seats rs
    WHERE rs.room_id = NEW.room_id
      AND rs.user_id = NEW.receiver_id
      AND rs.seat_index IS NOT NULL
      AND rs.seat_index >= 0
      AND rs.seat_index < 10;

    IF NOT FOUND THEN
      RETURN NEW;
    END IF;

    v_team := CASE WHEN v_seat_index < 5 THEN 'a' ELSE 'b' END;
  END IF;

  INSERT INTO public.room_pk_gift_contributions (
    session_id,
    gift_log_id,
    receiver_id,
    seat_index,
    team,
    amount
  )
  VALUES (
    v_session.id,
    NEW.id,
    NEW.receiver_id,
    v_seat_index,
    v_team,
    NEW.amount
  )
  ON CONFLICT (gift_log_id) DO NOTHING;

  IF FOUND THEN
    IF v_team = 'a' THEN
      UPDATE public.room_pk_sessions
      SET team_a_score = team_a_score + NEW.amount
      WHERE id = v_session.id;
    ELSE
      UPDATE public.room_pk_sessions
      SET team_b_score = team_b_score + NEW.amount
      WHERE id = v_session.id;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.start_room_solo_pk_session(uuid, integer) TO authenticated;
