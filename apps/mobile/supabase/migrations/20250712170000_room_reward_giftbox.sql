-- Room Reward Gift Box: levels, reward pool, rules, claims, progress + open RPCs.

CREATE TABLE IF NOT EXISTS public.room_reward_levels (
  level integer PRIMARY KEY CHECK (level BETWEEN 1 AND 5),
  required_points bigint NOT NULL CHECK (required_points > 0),
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.room_reward_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  level integer NOT NULL REFERENCES public.room_reward_levels (level) ON DELETE CASCADE,
  title text NOT NULL DEFAULT '',
  image_url text NOT NULL DEFAULT '',
  reward_type text NOT NULL DEFAULT 'coins'
    CHECK (reward_type IN ('coins', 'shop_item')),
  coin_amount integer NOT NULL DEFAULT 0 CHECK (coin_amount >= 0),
  shop_item_id uuid REFERENCES public.shop_items (id) ON DELETE SET NULL,
  weight integer NOT NULL DEFAULT 1 CHECK (weight > 0),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  is_featured boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS room_reward_items_level_idx
  ON public.room_reward_items (level, is_active, sort_order);

CREATE TABLE IF NOT EXISTS public.room_reward_rules (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  rules jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.room_reward_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  room_id uuid NOT NULL REFERENCES public.rooms (id) ON DELETE CASCADE,
  level integer NOT NULL REFERENCES public.room_reward_levels (level),
  reward_item_id uuid REFERENCES public.room_reward_items (id) ON DELETE SET NULL,
  reward_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, room_id, level)
);

CREATE INDEX IF NOT EXISTS room_reward_claims_user_room_idx
  ON public.room_reward_claims (user_id, room_id, created_at DESC);

INSERT INTO public.room_reward_levels (level, required_points, sort_order)
VALUES
  (1, 100000, 1),
  (2, 500000, 2),
  (3, 2000000, 3),
  (4, 5000000, 4),
  (5, 12000000, 5)
ON CONFLICT (level) DO NOTHING;

INSERT INTO public.room_reward_rules (id, rules)
VALUES (
  1,
  '[
    "Contribute energy by sending gifts in this room. Gift coins count toward your progress.",
    "Each level has its own point requirement. Reach the required energy to open that level gift box.",
    "Each level can be opened once per room. Rewards are randomly selected from that level pool.",
    "Rewards may be coins or inventory items configured by the platform."
  ]'::jsonb
)
ON CONFLICT (id) DO NOTHING;

-- Allow room_reward transaction type for coin grants
ALTER TABLE public.transactions
  DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;

ALTER TABLE public.transactions
  ADD CONSTRAINT transactions_transaction_type_check
  CHECK (transaction_type = ANY (ARRAY[
    'recharge'::text,
    'gift_sent'::text,
    'gift_received'::text,
    'lucky_gift_bonus'::text,
    'game_win'::text,
    'game_loss'::text,
    'withdrawal'::text,
    'purchase'::text,
    'agency_commission'::text,
    'salary_payout'::text,
    'transfer_out'::text,
    'transfer_in'::text,
    'exchange'::text,
    'rupee_game_entry'::text,
    'rupee_game_refund'::text,
    'lucky_pro_gift_bonus'::text,
    'room_reward'::text
  ]));

ALTER TABLE public.room_reward_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_reward_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_reward_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_reward_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS room_reward_levels_read ON public.room_reward_levels;
CREATE POLICY room_reward_levels_read ON public.room_reward_levels
  FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS room_reward_items_read ON public.room_reward_items;
CREATE POLICY room_reward_items_read ON public.room_reward_items
  FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS room_reward_rules_read ON public.room_reward_rules;
CREATE POLICY room_reward_rules_read ON public.room_reward_rules
  FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS room_reward_claims_read_own ON public.room_reward_claims;
CREATE POLICY room_reward_claims_read_own ON public.room_reward_claims
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.get_room_reward_progress(p_room_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_energy bigint := 0;
  v_current_level integer := 1;
  v_levels json;
  v_items json;
  v_claimed integer[];
  v_rules json;
BEGIN
  IF p_room_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Room required');
  END IF;

  IF v_user_id IS NOT NULL THEN
    SELECT COALESCE(SUM(gl.amount), 0)::bigint
    INTO v_energy
    FROM public.gift_logs gl
    WHERE gl.room_id = p_room_id
      AND gl.sender_id = v_user_id;

    SELECT COALESCE(array_agg(c.level ORDER BY c.level), '{}')
    INTO v_claimed
    FROM public.room_reward_claims c
    WHERE c.user_id = v_user_id
      AND c.room_id = p_room_id;
  ELSE
    v_claimed := '{}';
  END IF;

  -- Working level: lowest active unclaimed level; if all claimed, highest level
  SELECT COALESCE(
    (
      SELECT l.level
      FROM public.room_reward_levels l
      WHERE l.is_active = true
        AND NOT (l.level = ANY (v_claimed))
      ORDER BY l.level ASC
      LIMIT 1
    ),
    (
      SELECT MAX(l.level)
      FROM public.room_reward_levels l
      WHERE l.is_active = true
    ),
    1
  )
  INTO v_current_level;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.level), '[]'::json)
  INTO v_levels
  FROM (
    SELECT
      l.level,
      l.required_points,
      l.is_active,
      l.sort_order,
      (l.level = ANY (v_claimed)) AS claimed,
      (v_energy >= l.required_points AND NOT (l.level = ANY (v_claimed))) AS can_open
    FROM public.room_reward_levels l
    WHERE l.is_active = true
  ) t;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.level, t.sort_order, t.created_at), '[]'::json)
  INTO v_items
  FROM (
    SELECT
      i.id,
      i.level,
      i.title,
      i.image_url,
      i.reward_type,
      i.coin_amount,
      i.shop_item_id,
      i.weight,
      i.sort_order,
      i.is_featured,
      i.created_at
    FROM public.room_reward_items i
    WHERE i.is_active = true
  ) t;

  SELECT COALESCE(r.rules, '[]'::jsonb)
  INTO v_rules
  FROM public.room_reward_rules r
  WHERE r.id = 1;

  RETURN json_build_object(
    'success', true,
    'energy', v_energy,
    'current_level', v_current_level,
    'claimed_levels', to_json(v_claimed),
    'levels', v_levels,
    'items', v_items,
    'rules', COALESCE(v_rules, '[]'::json)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.open_room_reward_box(
  p_room_id uuid,
  p_level integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_energy bigint := 0;
  v_required bigint;
  v_item public.room_reward_items%ROWTYPE;
  v_total_weight integer;
  v_pick integer;
  v_running integer := 0;
  v_claim_id uuid;
  v_expires timestamptz;
  v_snapshot jsonb;
  v_duration integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_room_id IS NULL OR p_level IS NULL OR p_level < 1 OR p_level > 5 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid params');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id) THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  SELECT l.required_points
  INTO v_required
  FROM public.room_reward_levels l
  WHERE l.level = p_level
    AND l.is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Level not found');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.room_reward_claims c
    WHERE c.user_id = v_user_id
      AND c.room_id = p_room_id
      AND c.level = p_level
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed');
  END IF;

  SELECT COALESCE(SUM(gl.amount), 0)::bigint
  INTO v_energy
  FROM public.gift_logs gl
  WHERE gl.room_id = p_room_id
    AND gl.sender_id = v_user_id;

  IF v_energy < v_required THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Not enough energy',
      'energy', v_energy,
      'required', v_required
    );
  END IF;

  SELECT COALESCE(SUM(i.weight), 0)
  INTO v_total_weight
  FROM public.room_reward_items i
  WHERE i.level = p_level
    AND i.is_active = true;

  IF v_total_weight <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No rewards configured');
  END IF;

  v_pick := 1 + floor(random() * v_total_weight)::integer;

  FOR v_item IN
    SELECT *
    FROM public.room_reward_items i
    WHERE i.level = p_level
      AND i.is_active = true
    ORDER BY i.sort_order, i.created_at
  LOOP
    v_running := v_running + v_item.weight;
    IF v_running >= v_pick THEN
      EXIT;
    END IF;
  END LOOP;

  IF v_item.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Reward pick failed');
  END IF;

  v_snapshot := jsonb_build_object(
    'id', v_item.id,
    'title', v_item.title,
    'image_url', v_item.image_url,
    'reward_type', v_item.reward_type,
    'coin_amount', v_item.coin_amount,
    'shop_item_id', v_item.shop_item_id,
    'level', p_level
  );

  IF v_item.reward_type = 'coins' AND v_item.coin_amount > 0 THEN
    UPDATE public.users
    SET coins = coins + v_item.coin_amount
    WHERE id = v_user_id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    ) VALUES (
      v_user_id,
      v_item.coin_amount,
      'coin',
      'room_reward',
      p_room_id
    );
  ELSIF v_item.reward_type = 'shop_item' AND v_item.shop_item_id IS NOT NULL THEN
    SELECT COALESCE(si.duration_days, 0)
    INTO v_duration
    FROM public.shop_items si
    WHERE si.id = v_item.shop_item_id
      AND si.is_active = true;

    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'message', 'Shop item missing');
    END IF;

    v_expires := CASE
      WHEN v_duration > 0 THEN now() + make_interval(days => v_duration)
      ELSE '9999-12-31'::timestamptz
    END;

    INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
    VALUES (v_user_id, v_item.shop_item_id, 'room_reward', v_expires)
    ON CONFLICT (user_id, item_id) DO NOTHING;
  END IF;

  INSERT INTO public.room_reward_claims (
    user_id, room_id, level, reward_item_id, reward_snapshot
  ) VALUES (
    v_user_id, p_room_id, p_level, v_item.id, v_snapshot
  )
  RETURNING id INTO v_claim_id;

  RETURN json_build_object(
    'success', true,
    'claim_id', v_claim_id,
    'reward', v_snapshot
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed');
  WHEN others THEN
    RETURN json_build_object(
      'success', false,
      'message', SQLERRM
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_room_reward_claims(p_room_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_rows json;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated', 'claims', '[]'::json);
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.created_at DESC), '[]'::json)
  INTO v_rows
  FROM (
    SELECT
      c.id,
      c.level,
      c.reward_snapshot,
      c.created_at
    FROM public.room_reward_claims c
    WHERE c.user_id = v_user_id
      AND c.room_id = p_room_id
  ) t;

  RETURN json_build_object('success', true, 'claims', v_rows);
END;
$function$;

GRANT SELECT ON public.room_reward_levels TO anon, authenticated, service_role;
GRANT SELECT ON public.room_reward_items TO anon, authenticated, service_role;
GRANT SELECT ON public.room_reward_rules TO anon, authenticated, service_role;
GRANT SELECT ON public.room_reward_claims TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_room_reward_progress(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.open_room_reward_box(uuid, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_room_reward_claims(uuid) TO authenticated, service_role;
