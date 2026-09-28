-- Rupee Game / Lucky Offer: campaigns, prizes, entries, help CMS + RPCs.

CREATE TABLE IF NOT EXISTS public.rupee_game_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL DEFAULT 'Rupee Game',
  subtitle text NOT NULL DEFAULT 'Get items worth a fortune for just a few coins',
  hero_image_url text,
  entry_price_coins integer NOT NULL DEFAULT 1 CHECK (entry_price_coins > 0),
  starts_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'ended', 'drawn')),
  max_entries_per_user integer NOT NULL DEFAULT 1 CHECK (max_entries_per_user > 0),
  draw_mode text NOT NULL DEFAULT 'manual'
    CHECK (draw_mode IN ('manual', 'auto_random')),
  refund_non_winners boolean NOT NULL DEFAULT true,
  announcement_hours integer NOT NULL DEFAULT 48 CHECK (announcement_hours > 0),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.rupee_game_prizes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.rupee_game_campaigns(id) ON DELETE CASCADE,
  name text NOT NULL,
  image_url text,
  original_value_label text NOT NULL DEFAULT '',
  participant_count integer NOT NULL DEFAULT 0 CHECK (participant_count >= 0),
  winner_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  drawn_at timestamptz,
  draw_status text NOT NULL DEFAULT 'pending'
    CHECK (draw_status IN ('pending', 'drawn', 'refunded')),
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rupee_game_prizes_campaign
  ON public.rupee_game_prizes (campaign_id, sort_order);

CREATE TABLE IF NOT EXISTS public.rupee_game_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.rupee_game_campaigns(id) ON DELETE CASCADE,
  prize_id uuid NOT NULL REFERENCES public.rupee_game_prizes(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  coins_paid integer NOT NULL CHECK (coins_paid > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (prize_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_rupee_game_entries_prize
  ON public.rupee_game_entries (prize_id);
CREATE INDEX IF NOT EXISTS idx_rupee_game_entries_user
  ON public.rupee_game_entries (user_id);
CREATE INDEX IF NOT EXISTS idx_rupee_game_entries_campaign
  ON public.rupee_game_entries (campaign_id);

CREATE TABLE IF NOT EXISTS public.rupee_game_help_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  section_key text NOT NULL UNIQUE
    CHECK (section_key IN ('intro', 'how_it_works', 'terms', 'faq', 'refund')),
  title text NOT NULL,
  content jsonb NOT NULL DEFAULT '{"items":[]}'::jsonb,
  sort_order integer NOT NULL DEFAULT 0,
  is_expanded_default boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_transaction_type_check
  CHECK (transaction_type = ANY (ARRAY[
    'recharge'::text, 'gift_sent'::text, 'gift_received'::text, 'lucky_gift_bonus'::text,
    'game_win'::text, 'game_loss'::text, 'withdrawal'::text, 'purchase'::text,
    'agency_commission'::text, 'salary_payout'::text, 'transfer_out'::text, 'transfer_in'::text, 'exchange'::text,
    'rupee_game_entry'::text, 'rupee_game_refund'::text
  ]));

INSERT INTO public.rupee_game_help_sections (section_key, title, content, sort_order, is_expanded_default)
VALUES
  (
    'intro',
    'One Coin Offer',
    '{"items":["Participation in the coin game allows you to win prizes which are too good to be true, for just a few coins."]}'::jsonb,
    0,
    true
  ),
  (
    'how_it_works',
    'How it works',
    '{"items":[
      "Login to the app.",
      "Open the Game tab from bottom navigation.",
      "Select a product from the campaign page.",
      "Confirm the coin payment.",
      "Receive a confirmation message for participation."
    ]}'::jsonb,
    1,
    false
  ),
  (
    'terms',
    'Terms and Conditions',
    '{"items":[
      "You can participate only once per prize per campaign (unless admin changes the limit).",
      "Refunds depend on the specific campaign settings.",
      "Eligibility criteria may apply to different users."
    ]}'::jsonb,
    2,
    false
  ),
  (
    'faq',
    'FAQs',
    '{"items":[
      "Q: What transaction is required? A: A coin purchase for the selected prize.",
      "Q: Does paying guarantee winning? A: No, winners are announced after the campaign ends.",
      "Q: How are winners announced? A: Within the configured hours on the app."
    ]}'::jsonb,
    3,
    false
  ),
  (
    'refund',
    'How to Refund',
    '{"items":[
      "Q: When do non-winners get refunded? A: If the campaign has refunds enabled, losers receive their entry coins back after the draw."
    ]}'::jsonb,
    4,
    false
  )
ON CONFLICT (section_key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.enter_rupee_game(p_prize_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_prize public.rupee_game_prizes%ROWTYPE;
  v_campaign public.rupee_game_campaigns%ROWTYPE;
  v_user_coins bigint;
  v_campaign_entries integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_prize
  FROM public.rupee_game_prizes
  WHERE id = p_prize_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Prize not found');
  END IF;

  IF v_prize.draw_status <> 'pending' THEN
    RETURN json_build_object('success', false, 'message', 'Prize draw already completed');
  END IF;

  SELECT * INTO v_campaign
  FROM public.rupee_game_campaigns
  WHERE id = v_prize.campaign_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Campaign not found');
  END IF;

  IF v_campaign.status <> 'active' OR NOT v_campaign.is_active THEN
    RETURN json_build_object('success', false, 'message', 'Campaign is not active');
  END IF;

  IF now() < v_campaign.starts_at OR now() > v_campaign.ends_at THEN
    RETURN json_build_object('success', false, 'message', 'Campaign is outside its date window');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.rupee_game_entries
    WHERE prize_id = p_prize_id AND user_id = v_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already participated in this prize');
  END IF;

  SELECT COUNT(*)::integer INTO v_campaign_entries
  FROM public.rupee_game_entries
  WHERE campaign_id = v_campaign.id AND user_id = v_user_id;

  IF v_campaign_entries >= v_campaign.max_entries_per_user THEN
    RETURN json_build_object('success', false, 'message', 'Campaign entry limit reached');
  END IF;

  SELECT coins INTO v_user_coins
  FROM public.users
  WHERE id = v_user_id
  FOR UPDATE;

  IF COALESCE(v_user_coins, 0) < v_campaign.entry_price_coins THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins');
  END IF;

  UPDATE public.users
  SET coins = coins - v_campaign.entry_price_coins
  WHERE id = v_user_id;

  INSERT INTO public.rupee_game_entries (
    campaign_id, prize_id, user_id, coins_paid
  )
  VALUES (
    v_campaign.id, p_prize_id, v_user_id, v_campaign.entry_price_coins
  );

  UPDATE public.rupee_game_prizes
  SET participant_count = participant_count + 1,
      updated_at = now()
  WHERE id = p_prize_id;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  )
  VALUES (
    v_user_id,
    -v_campaign.entry_price_coins,
    'coins',
    'rupee_game_entry',
    p_prize_id
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Participation confirmed',
    'coins_paid', v_campaign.entry_price_coins,
    'participant_count', v_prize.participant_count + 1
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.draw_rupee_game_winner(
  p_prize_id uuid,
  p_user_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_prize public.rupee_game_prizes%ROWTYPE;
  v_campaign public.rupee_game_campaigns%ROWTYPE;
  v_winner_id uuid;
  v_entry_count integer;
BEGIN
  SELECT * INTO v_prize
  FROM public.rupee_game_prizes
  WHERE id = p_prize_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Prize not found');
  END IF;

  IF v_prize.draw_status <> 'pending' THEN
    RETURN json_build_object('success', false, 'message', 'Prize already drawn');
  END IF;

  SELECT * INTO v_campaign
  FROM public.rupee_game_campaigns
  WHERE id = v_prize.campaign_id;

  SELECT COUNT(*)::integer INTO v_entry_count
  FROM public.rupee_game_entries
  WHERE prize_id = p_prize_id;

  IF v_entry_count = 0 THEN
    RETURN json_build_object('success', false, 'message', 'No entries to draw from');
  END IF;

  IF p_user_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.rupee_game_entries
      WHERE prize_id = p_prize_id AND user_id = p_user_id
    ) THEN
      RETURN json_build_object('success', false, 'message', 'Selected user has no entry for this prize');
    END IF;
    v_winner_id := p_user_id;
  ELSE
    SELECT user_id INTO v_winner_id
    FROM public.rupee_game_entries
    WHERE prize_id = p_prize_id
    ORDER BY random()
    LIMIT 1;
  END IF;

  UPDATE public.rupee_game_prizes
  SET winner_user_id = v_winner_id,
      drawn_at = now(),
      draw_status = 'drawn',
      updated_at = now()
  WHERE id = p_prize_id;

  RETURN json_build_object(
    'success', true,
    'winner_user_id', v_winner_id,
    'prize_id', p_prize_id
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.refund_rupee_game_losers(p_prize_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_prize public.rupee_game_prizes%ROWTYPE;
  v_campaign public.rupee_game_campaigns%ROWTYPE;
  v_refunded integer := 0;
  r record;
BEGIN
  SELECT * INTO v_prize
  FROM public.rupee_game_prizes
  WHERE id = p_prize_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Prize not found');
  END IF;

  IF v_prize.draw_status <> 'drawn' THEN
    RETURN json_build_object('success', false, 'message', 'Draw winner before refunding');
  END IF;

  SELECT * INTO v_campaign
  FROM public.rupee_game_campaigns
  WHERE id = v_prize.campaign_id;

  IF NOT v_campaign.refund_non_winners THEN
    RETURN json_build_object('success', false, 'message', 'Refunds disabled for this campaign');
  END IF;

  IF v_prize.draw_status = 'refunded' THEN
    RETURN json_build_object('success', false, 'message', 'Already refunded');
  END IF;

  FOR r IN
    SELECT user_id, coins_paid
    FROM public.rupee_game_entries
    WHERE prize_id = p_prize_id
      AND user_id IS DISTINCT FROM v_prize.winner_user_id
  LOOP
    UPDATE public.users
    SET coins = coins + r.coins_paid
    WHERE id = r.user_id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    )
    VALUES (
      r.user_id,
      r.coins_paid,
      'coins',
      'rupee_game_refund',
      p_prize_id
    );

    v_refunded := v_refunded + 1;
  END LOOP;

  UPDATE public.rupee_game_prizes
  SET draw_status = 'refunded',
      updated_at = now()
  WHERE id = p_prize_id;

  RETURN json_build_object(
    'success', true,
    'refunded_count', v_refunded
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.auto_draw_ended_campaigns()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_campaign record;
  v_prize record;
  v_drawn integer := 0;
  v_result json;
BEGIN
  FOR v_campaign IN
    SELECT *
    FROM public.rupee_game_campaigns
    WHERE draw_mode = 'auto_random'
      AND status = 'active'
      AND ends_at <= now()
  LOOP
    UPDATE public.rupee_game_campaigns
    SET status = 'ended', updated_at = now()
    WHERE id = v_campaign.id;

    FOR v_prize IN
      SELECT id FROM public.rupee_game_prizes
      WHERE campaign_id = v_campaign.id AND draw_status = 'pending'
    LOOP
      v_result := public.draw_rupee_game_winner(v_prize.id, NULL);
      IF (v_result->>'success')::boolean THEN
        v_drawn := v_drawn + 1;
        IF v_campaign.refund_non_winners THEN
          PERFORM public.refund_rupee_game_losers(v_prize.id);
        END IF;
      END IF;
    END LOOP;

    UPDATE public.rupee_game_campaigns
    SET status = 'drawn', updated_at = now()
    WHERE id = v_campaign.id;
  END LOOP;

  RETURN json_build_object('success', true, 'prizes_drawn', v_drawn);
END;
$function$;

ALTER TABLE public.rupee_game_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rupee_game_prizes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rupee_game_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rupee_game_help_sections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rupee_game_campaigns_read ON public.rupee_game_campaigns;
CREATE POLICY rupee_game_campaigns_read ON public.rupee_game_campaigns
  FOR SELECT TO public
  USING (is_active = true AND status IN ('active', 'ended', 'drawn'));

DROP POLICY IF EXISTS rupee_game_prizes_read ON public.rupee_game_prizes;
CREATE POLICY rupee_game_prizes_read ON public.rupee_game_prizes
  FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS rupee_game_help_read ON public.rupee_game_help_sections;
CREATE POLICY rupee_game_help_read ON public.rupee_game_help_sections
  FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS rupee_game_entries_own_read ON public.rupee_game_entries;
CREATE POLICY rupee_game_entries_own_read ON public.rupee_game_entries
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

GRANT SELECT ON public.rupee_game_campaigns TO anon, authenticated;
GRANT SELECT ON public.rupee_game_prizes TO anon, authenticated;
GRANT SELECT ON public.rupee_game_help_sections TO anon, authenticated;
GRANT SELECT ON public.rupee_game_entries TO authenticated;
GRANT EXECUTE ON FUNCTION public.enter_rupee_game(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.draw_rupee_game_winner(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.refund_rupee_game_losers(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.auto_draw_ended_campaigns() TO service_role;
