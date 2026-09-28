-- Lucky Bag system: room/world coin bags with admin-configurable tiers.

CREATE TABLE IF NOT EXISTS public.lucky_bag_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  label text NOT NULL,
  total_coins integer NOT NULL CHECK (total_coins > 0),
  recipient_options integer[] NOT NULL DEFAULT '{5,10,20,30}',
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.lucky_bag_rules (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  rules jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.lucky_bags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  scope text NOT NULL CHECK (scope IN ('room', 'world')),
  tier_id uuid REFERENCES public.lucky_bag_tiers(id) ON DELETE SET NULL,
  total_coins integer NOT NULL CHECK (total_coins > 0),
  recipient_count integer NOT NULL CHECK (recipient_count > 0),
  claimed_count integer NOT NULL DEFAULT 0,
  remaining_coins integer NOT NULL,
  coin_splits integer[] NOT NULL,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'finished', 'expired')),
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lucky_bags_room_active
  ON public.lucky_bags (room_id, scope, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_lucky_bags_world_active
  ON public.lucky_bags (scope, status, created_at DESC)
  WHERE scope = 'world';

CREATE TABLE IF NOT EXISTS public.lucky_bag_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bag_id uuid NOT NULL REFERENCES public.lucky_bags(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  coins integer NOT NULL CHECK (coins > 0),
  claimed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (bag_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_lucky_bag_claims_bag
  ON public.lucky_bag_claims (bag_id);

INSERT INTO public.lucky_bag_tiers (label, total_coins, recipient_options, sort_order)
VALUES
  ('1K', 1000, '{5,10,20,30}', 1),
  ('2K', 2000, '{5,10,20,30}', 2),
  ('3K', 3000, '{5,10,20,30}', 3),
  ('5K', 5000, '{5,10,20,30}', 4)
ON CONFLICT DO NOTHING;

INSERT INTO public.lucky_bag_rules (id, rules)
VALUES (
  1,
  '[
    "Lucky bags can be sent to other users. Room lucky bags are only displayed and collected in the current room.",
    "World blessing bags are displayed outside the room with a floating banner. Tap it to enter the room and claim.",
    "Choose the bag amount and number of recipients. Claimers randomly receive gold coins from the pool.",
    "Sending lucky bags does not increase charm value."
  ]'::jsonb
)
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.generate_lucky_bag_splits(
  p_total integer,
  p_count integer
)
RETURNS integer[]
LANGUAGE plpgsql
IMMUTABLE
AS $function$
DECLARE
  v_splits integer[] := '{}';
  v_remaining integer := p_total;
  v_min integer := 1;
  i integer;
  v_max integer;
  v_amount integer;
BEGIN
  IF p_count <= 0 OR p_total < p_count THEN
    RAISE EXCEPTION 'Invalid split params';
  END IF;

  FOR i IN 1..p_count - 1 LOOP
    v_max := v_remaining - (p_count - i) * v_min;
    IF v_max < v_min THEN
      v_amount := v_min;
    ELSE
      v_amount := v_min + floor(random() * (v_max - v_min + 1))::integer;
    END IF;
    v_splits := array_append(v_splits, v_amount);
    v_remaining := v_remaining - v_amount;
  END LOOP;

  v_splits := array_append(v_splits, v_remaining);
  RETURN v_splits;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_lucky_bag(
  p_room_id uuid,
  p_scope text,
  p_tier_id uuid,
  p_recipient_count integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_tier public.lucky_bag_tiers%ROWTYPE;
  v_sender_coins bigint;
  v_splits integer[];
  v_bag_id uuid;
  v_sender_name text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_scope NOT IN ('room', 'world') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid scope');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id) THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  SELECT * INTO v_tier
  FROM public.lucky_bag_tiers
  WHERE id = p_tier_id AND is_active = TRUE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Tier not found');
  END IF;

  IF NOT (p_recipient_count = ANY (v_tier.recipient_options)) THEN
    RETURN json_build_object('success', false, 'message', 'Invalid recipient count');
  END IF;

  SELECT coins INTO v_sender_coins
  FROM public.users
  WHERE id = v_user_id
  FOR UPDATE;

  IF COALESCE(v_sender_coins, 0) < v_tier.total_coins THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins');
  END IF;

  v_splits := public.generate_lucky_bag_splits(v_tier.total_coins, p_recipient_count);

  UPDATE public.users
  SET coins = coins - v_tier.total_coins
  WHERE id = v_user_id;

  INSERT INTO public.lucky_bags (
    room_id,
    sender_id,
    scope,
    tier_id,
    total_coins,
    recipient_count,
    remaining_coins,
    coin_splits,
    expires_at
  )
  VALUES (
    p_room_id,
    v_user_id,
    p_scope,
    p_tier_id,
    v_tier.total_coins,
    p_recipient_count,
    v_tier.total_coins,
    v_splits,
    now() + interval '24 hours'
  )
  RETURNING id INTO v_bag_id;

  SELECT username INTO v_sender_name FROM public.users WHERE id = v_user_id;

  RETURN json_build_object(
    'success', true,
    'bag_id', v_bag_id,
    'scope', p_scope,
    'total_coins', v_tier.total_coins,
    'recipient_count', p_recipient_count,
    'sender_name', COALESCE(v_sender_name, 'User')
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.claim_lucky_bag(p_bag_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_bag public.lucky_bags%ROWTYPE;
  v_claim_amount integer;
  v_claim_index integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_bag
  FROM public.lucky_bags
  WHERE id = p_bag_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Bag not found');
  END IF;

  IF v_bag.status <> 'active' THEN
    RETURN json_build_object('success', false, 'message', 'Bag is no longer active');
  END IF;

  IF v_bag.expires_at <= now() THEN
    UPDATE public.lucky_bags SET status = 'expired' WHERE id = p_bag_id;
    RETURN json_build_object('success', false, 'message', 'Bag expired');
  END IF;

  IF v_bag.claimed_count >= v_bag.recipient_count THEN
    UPDATE public.lucky_bags SET status = 'finished' WHERE id = p_bag_id;
    RETURN json_build_object('success', false, 'message', 'Bag fully claimed');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.lucky_bag_claims
    WHERE bag_id = p_bag_id AND user_id = v_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed');
  END IF;

  IF v_bag.sender_id = v_user_id THEN
    RETURN json_build_object('success', false, 'message', 'Sender cannot claim own bag');
  END IF;

  v_claim_index := v_bag.claimed_count + 1;
  v_claim_amount := v_bag.coin_splits[v_claim_index];

  INSERT INTO public.lucky_bag_claims (bag_id, user_id, coins)
  VALUES (p_bag_id, v_user_id, v_claim_amount);

  UPDATE public.users
  SET coins = coins + v_claim_amount
  WHERE id = v_user_id;

  UPDATE public.lucky_bags
  SET
    claimed_count = claimed_count + 1,
    remaining_coins = remaining_coins - v_claim_amount,
    status = CASE
      WHEN claimed_count + 1 >= recipient_count THEN 'finished'
      ELSE status
    END
  WHERE id = p_bag_id;

  RETURN json_build_object(
    'success', true,
    'coins', v_claim_amount,
    'remaining_slots', v_bag.recipient_count - v_bag.claimed_count - 1
  );
END;
$function$;

ALTER TABLE public.lucky_bag_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lucky_bag_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lucky_bags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lucky_bag_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lucky_bag_tiers_read ON public.lucky_bag_tiers;
CREATE POLICY lucky_bag_tiers_read ON public.lucky_bag_tiers
  FOR SELECT TO authenticated USING (is_active = true);

DROP POLICY IF EXISTS lucky_bag_rules_read ON public.lucky_bag_rules;
CREATE POLICY lucky_bag_rules_read ON public.lucky_bag_rules
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS lucky_bags_read ON public.lucky_bags;
CREATE POLICY lucky_bags_read ON public.lucky_bags
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS lucky_bag_claims_read ON public.lucky_bag_claims;
CREATE POLICY lucky_bag_claims_read ON public.lucky_bag_claims
  FOR SELECT TO authenticated USING (true);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'lucky_bags'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.lucky_bags;
  END IF;
END $$;

GRANT SELECT ON public.lucky_bag_tiers TO authenticated;
GRANT SELECT ON public.lucky_bag_rules TO authenticated;
GRANT SELECT ON public.lucky_bags TO authenticated;
GRANT SELECT ON public.lucky_bag_claims TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_lucky_bag(uuid, text, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_lucky_bag(uuid) TO authenticated;
