-- Team PK: timed 5v5 gift battle in voice rooms (10 mic seats).

CREATE TABLE IF NOT EXISTS public.room_pk_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  started_by uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'finished', 'cancelled')),
  duration_minutes integer NOT NULL CHECK (duration_minutes IN (5, 15, 30)),
  team_a_score bigint NOT NULL DEFAULT 0,
  team_b_score bigint NOT NULL DEFAULT 0,
  winner_team text CHECK (winner_team IN ('a', 'b', 'tie')),
  started_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz NOT NULL,
  finished_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_room_pk_sessions_room_active
  ON public.room_pk_sessions (room_id, status, started_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_room_pk_sessions_one_active
  ON public.room_pk_sessions (room_id)
  WHERE status = 'active';

CREATE TABLE IF NOT EXISTS public.room_pk_gift_contributions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.room_pk_sessions(id) ON DELETE CASCADE,
  gift_log_id uuid NOT NULL REFERENCES public.gift_logs(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  seat_index integer NOT NULL CHECK (seat_index >= 0 AND seat_index < 10),
  team text NOT NULL CHECK (team IN ('a', 'b')),
  amount integer NOT NULL CHECK (amount > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (gift_log_id)
);

CREATE INDEX IF NOT EXISTS idx_room_pk_contributions_session
  ON public.room_pk_gift_contributions (session_id, receiver_id);

CREATE OR REPLACE FUNCTION public.user_can_manage_room(p_room_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rooms r
    WHERE r.id = p_room_id AND r.host_id = p_user_id
  )
  OR EXISTS (
    SELECT 1 FROM public.room_members rm
    WHERE rm.room_id = p_room_id
      AND rm.user_id = p_user_id
      AND rm.role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.finish_room_pk_session(p_session_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_session public.room_pk_sessions%ROWTYPE;
  v_winner text;
BEGIN
  SELECT * INTO v_session
  FROM public.room_pk_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Session not found');
  END IF;

  IF v_session.status <> 'active' THEN
    RETURN json_build_object(
      'success', true,
      'session_id', v_session.id,
      'status', v_session.status,
      'winner_team', v_session.winner_team,
      'team_a_score', v_session.team_a_score,
      'team_b_score', v_session.team_b_score
    );
  END IF;

  v_winner := CASE
    WHEN v_session.team_a_score > v_session.team_b_score THEN 'a'
    WHEN v_session.team_b_score > v_session.team_a_score THEN 'b'
    ELSE 'tie'
  END;

  UPDATE public.room_pk_sessions
  SET
    status = 'finished',
    winner_team = v_winner,
    finished_at = now()
  WHERE id = p_session_id;

  RETURN json_build_object(
    'success', true,
    'session_id', p_session_id,
    'status', 'finished',
    'winner_team', v_winner,
    'team_a_score', v_session.team_a_score,
    'team_b_score', v_session.team_b_score
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.sync_room_pk_session(p_room_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_session public.room_pk_sessions%ROWTYPE;
  v_result json;
BEGIN
  SELECT * INTO v_session
  FROM public.room_pk_sessions
  WHERE room_id = p_room_id AND status = 'active'
  ORDER BY started_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', true, 'session', null);
  END IF;

  IF v_session.ends_at <= now() THEN
    v_result := public.finish_room_pk_session(v_session.id);
    RETURN json_build_object(
      'success', true,
      'session', (
        SELECT row_to_json(s)
        FROM public.room_pk_sessions s
        WHERE s.id = v_session.id
      ),
      'auto_finished', true,
      'finish', v_result
    );
  END IF;

  RETURN json_build_object(
    'success', true,
    'session', row_to_json(v_session),
    'auto_finished', false
  );
END;
$function$;

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
    ends_at
  )
  VALUES (
    p_room_id,
    v_user_id,
    p_duration_minutes,
    v_ends_at
  )
  RETURNING id INTO v_session_id;

  UPDATE public.rooms
  SET mic_count = 10
  WHERE id = p_room_id;

  RETURN json_build_object(
    'success', true,
    'session_id', v_session_id,
    'ends_at', v_ends_at,
    'duration_minutes', p_duration_minutes
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.stop_room_pk_session(p_session_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_session public.room_pk_sessions%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_session
  FROM public.room_pk_sessions
  WHERE id = p_session_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Session not found');
  END IF;

  IF NOT public.user_can_manage_room(v_session.room_id, v_user_id) THEN
    RETURN json_build_object('success', false, 'message', 'Not authorized');
  END IF;

  RETURN public.finish_room_pk_session(p_session_id);
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

DROP TRIGGER IF EXISTS gift_logs_attribute_pk ON public.gift_logs;
CREATE TRIGGER gift_logs_attribute_pk
  AFTER INSERT ON public.gift_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.attribute_pk_gift();

ALTER TABLE public.room_pk_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_pk_gift_contributions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS room_pk_sessions_read ON public.room_pk_sessions;
CREATE POLICY room_pk_sessions_read ON public.room_pk_sessions
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS room_pk_contributions_read ON public.room_pk_gift_contributions;
CREATE POLICY room_pk_contributions_read ON public.room_pk_gift_contributions
  FOR SELECT TO authenticated USING (true);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'room_pk_sessions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.room_pk_sessions;
  END IF;
END $$;

GRANT SELECT ON public.room_pk_sessions TO authenticated;
GRANT SELECT ON public.room_pk_gift_contributions TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_room_pk_session(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stop_room_pk_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_room_pk_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finish_room_pk_session(uuid) TO authenticated;
