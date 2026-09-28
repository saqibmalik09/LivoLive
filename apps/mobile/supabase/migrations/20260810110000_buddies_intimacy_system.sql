-- Buddies: Homie / Friend / Bestie close-friends system
-- Intimacy = lifetime gift_logs.amount both directions
-- Cap: 6 close friends per user across all buddy tiers

CREATE TABLE IF NOT EXISTS public.user_buddies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  user_b uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  tier text NOT NULL CHECK (tier IN ('friend', 'bestie', 'homie')),
  intimacy_at_bind bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_buddies_ordered CHECK (user_a < user_b),
  CONSTRAINT user_buddies_unique_pair UNIQUE (user_a, user_b)
);

CREATE INDEX IF NOT EXISTS user_buddies_user_a_idx ON public.user_buddies (user_a);
CREATE INDEX IF NOT EXISTS user_buddies_user_b_idx ON public.user_buddies (user_b);
CREATE INDEX IF NOT EXISTS user_buddies_tier_idx ON public.user_buddies (tier);

CREATE TABLE IF NOT EXISTS public.buddy_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  tier text NOT NULL CHECK (tier IN ('friend', 'bestie', 'homie')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  CONSTRAINT buddy_invitations_not_self CHECK (inviter_id <> invitee_id)
);

CREATE INDEX IF NOT EXISTS buddy_invitations_invitee_pending_idx
  ON public.buddy_invitations (invitee_id)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS buddy_invitations_inviter_pending_idx
  ON public.buddy_invitations (inviter_id)
  WHERE status = 'pending';

-- One pending invite per pair+tier (either direction)
CREATE UNIQUE INDEX IF NOT EXISTS buddy_invitations_pending_pair_tier_uidx
  ON public.buddy_invitations (
    LEAST(inviter_id, invitee_id),
    GREATEST(inviter_id, invitee_id),
    tier
  )
  WHERE status = 'pending';

ALTER TABLE public.user_buddies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.buddy_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_buddies_select ON public.user_buddies;
CREATE POLICY user_buddies_select ON public.user_buddies
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS buddy_invitations_select ON public.buddy_invitations;
CREATE POLICY buddy_invitations_select ON public.buddy_invitations
  FOR SELECT TO authenticated
  USING (auth.uid() = inviter_id OR auth.uid() = invitee_id);

CREATE OR REPLACE FUNCTION public.buddy_tier_threshold(p_tier text)
RETURNS bigint
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE lower(p_tier)
    WHEN 'friend' THEN 300000::bigint
    WHEN 'bestie' THEN 2000000::bigint
    WHEN 'homie' THEN 5000000::bigint
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_intimacy(p_user_a uuid, p_user_b uuid)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(gl.amount), 0)::bigint
  FROM public.gift_logs gl
  WHERE (gl.sender_id = p_user_a AND gl.receiver_id = p_user_b)
     OR (gl.sender_id = p_user_b AND gl.receiver_id = p_user_a);
$$;

CREATE OR REPLACE FUNCTION public._buddy_pair_ordered(p_a uuid, p_b uuid, OUT o_a uuid, OUT o_b uuid)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_a < p_b THEN
    o_a := p_a;
    o_b := p_b;
  ELSE
    o_a := p_b;
    o_b := p_a;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.count_user_close_friends(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)::integer
  FROM public.user_buddies ub
  WHERE ub.user_a = p_user_id OR ub.user_b = p_user_id;
$$;

CREATE OR REPLACE FUNCTION public.are_mutual_followers(p_a uuid, p_b uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.follows f
    WHERE f.follower_id = p_a AND f.following_id = p_b
  ) AND EXISTS (
    SELECT 1 FROM public.follows f
    WHERE f.follower_id = p_b AND f.following_id = p_a
  );
$$;

CREATE OR REPLACE FUNCTION public.list_buddy_eligible(p_tier text)
RETURNS TABLE (
  user_id uuid,
  username text,
  avatar_url text,
  intimacy bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_threshold bigint;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_threshold := public.buddy_tier_threshold(p_tier);
  IF v_threshold IS NULL THEN
    RAISE EXCEPTION 'Invalid tier';
  END IF;

  IF public.count_user_close_friends(v_me) >= 6 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH mutual AS (
    SELECT f1.following_id AS other_id
    FROM public.follows f1
    JOIN public.follows f2
      ON f2.follower_id = f1.following_id
     AND f2.following_id = f1.follower_id
    WHERE f1.follower_id = v_me
  ),
  intimacy AS (
    SELECT
      m.other_id,
      public.get_user_intimacy(v_me, m.other_id) AS score
    FROM mutual m
  )
  SELECT
    u.id,
    u.username,
    u.avatar_url,
    i.score
  FROM intimacy i
  JOIN public.users u ON u.id = i.other_id
  WHERE i.score >= v_threshold
    AND public.count_user_close_friends(i.other_id) < 6
    AND NOT EXISTS (
      SELECT 1 FROM public.user_buddies ub
      WHERE (ub.user_a = LEAST(v_me, i.other_id) AND ub.user_b = GREATEST(v_me, i.other_id))
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.buddy_invitations bi
      WHERE bi.status = 'pending'
        AND bi.tier = lower(p_tier)
        AND (
          (bi.inviter_id = v_me AND bi.invitee_id = i.other_id)
          OR (bi.inviter_id = i.other_id AND bi.invitee_id = v_me)
        )
    )
  ORDER BY i.score DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.invite_buddy(p_invitee_id uuid, p_tier text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_tier text := lower(p_tier);
  v_threshold bigint;
  v_intimacy bigint;
  v_id uuid;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;
  IF p_invitee_id IS NULL OR p_invitee_id = v_me THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid invitee');
  END IF;

  v_threshold := public.buddy_tier_threshold(v_tier);
  IF v_threshold IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid tier');
  END IF;

  IF public.count_user_close_friends(v_me) >= 6 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Close Friends limit reached (6/6)');
  END IF;
  IF public.count_user_close_friends(p_invitee_id) >= 6 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Their Close Friends list is full');
  END IF;

  IF NOT public.are_mutual_followers(v_me, p_invitee_id) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Mutual follow required');
  END IF;

  v_intimacy := public.get_user_intimacy(v_me, p_invitee_id);
  IF v_intimacy < v_threshold THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', format('Need %s intimacy (current %s)', v_threshold, v_intimacy)
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_buddies ub
    WHERE ub.user_a = LEAST(v_me, p_invitee_id)
      AND ub.user_b = GREATEST(v_me, p_invitee_id)
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Already close friends');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.buddy_invitations bi
    WHERE bi.status = 'pending'
      AND bi.tier = v_tier
      AND (
        (bi.inviter_id = v_me AND bi.invitee_id = p_invitee_id)
        OR (bi.inviter_id = p_invitee_id AND bi.invitee_id = v_me)
      )
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invitation already pending');
  END IF;

  INSERT INTO public.buddy_invitations (inviter_id, invitee_id, tier, status)
  VALUES (v_me, p_invitee_id, v_tier, 'pending')
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'invitation_id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_buddy_invite(p_invitation_id uuid, p_accept boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_inv public.buddy_invitations%ROWTYPE;
  v_intimacy bigint;
  v_a uuid;
  v_b uuid;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_inv
  FROM public.buddy_invitations
  WHERE id = p_invitation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invitation not found');
  END IF;
  IF v_inv.invitee_id <> v_me THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not your invitation');
  END IF;
  IF v_inv.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Already handled');
  END IF;

  IF NOT p_accept THEN
    UPDATE public.buddy_invitations
    SET status = 'rejected', responded_at = now()
    WHERE id = p_invitation_id;
    RETURN jsonb_build_object('success', true, 'status', 'rejected');
  END IF;

  IF public.count_user_close_friends(v_inv.inviter_id) >= 6
     OR public.count_user_close_friends(v_inv.invitee_id) >= 6 THEN
    UPDATE public.buddy_invitations
    SET status = 'cancelled', responded_at = now()
    WHERE id = p_invitation_id;
    RETURN jsonb_build_object('success', false, 'message', 'Close Friends limit reached');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_buddies ub
    WHERE ub.user_a = LEAST(v_inv.inviter_id, v_inv.invitee_id)
      AND ub.user_b = GREATEST(v_inv.inviter_id, v_inv.invitee_id)
  ) THEN
    UPDATE public.buddy_invitations
    SET status = 'accepted', responded_at = now()
    WHERE id = p_invitation_id;
    RETURN jsonb_build_object('success', true, 'status', 'accepted');
  END IF;

  v_intimacy := public.get_user_intimacy(v_inv.inviter_id, v_inv.invitee_id);
  v_a := LEAST(v_inv.inviter_id, v_inv.invitee_id);
  v_b := GREATEST(v_inv.inviter_id, v_inv.invitee_id);

  INSERT INTO public.user_buddies (user_a, user_b, tier, intimacy_at_bind)
  VALUES (v_a, v_b, v_inv.tier, v_intimacy);

  UPDATE public.buddy_invitations
  SET status = 'accepted', responded_at = now()
  WHERE id = p_invitation_id;

  -- Cancel other pending invites between this pair
  UPDATE public.buddy_invitations
  SET status = 'cancelled', responded_at = now()
  WHERE status = 'pending'
    AND id <> p_invitation_id
    AND (
      (inviter_id = v_inv.inviter_id AND invitee_id = v_inv.invitee_id)
      OR (inviter_id = v_inv.invitee_id AND invitee_id = v_inv.inviter_id)
    );

  RETURN jsonb_build_object('success', true, 'status', 'accepted', 'tier', v_inv.tier);
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_buddy(p_other_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_deleted integer;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  DELETE FROM public.user_buddies ub
  WHERE ub.user_a = LEAST(v_me, p_other_user_id)
    AND ub.user_b = GREATEST(v_me, p_other_user_id);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted = 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not buddies');
  END IF;
  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.list_user_intimacy_board(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_couple jsonb := NULL;
  v_buddies jsonb := '[]'::jsonb;
  v_count integer;
BEGIN
  -- Existing CP couple
  SELECT jsonb_build_object(
    'kind', 'couple',
    'tier', 'couple',
    'user_id', CASE WHEN c.user1_id = p_user_id THEN c.user2_id ELSE c.user1_id END,
    'username', u.username,
    'avatar_url', u.avatar_url,
    'intimacy', COALESCE(c.cp_exp, 0),
    'days', GREATEST(0, (EXTRACT(EPOCH FROM (now() - c.created_at)) / 86400)::integer),
    'created_at', c.created_at,
    'cp_level', COALESCE(c.cp_level, 0)
  )
  INTO v_couple
  FROM public.couples c
  JOIN public.users u ON u.id = CASE WHEN c.user1_id = p_user_id THEN c.user2_id ELSE c.user1_id END
  WHERE c.user1_id = p_user_id OR c.user2_id = p_user_id
  ORDER BY c.created_at DESC
  LIMIT 1;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
  INTO v_buddies
  FROM (
    SELECT
      'buddy'::text AS kind,
      ub.tier,
      CASE WHEN ub.user_a = p_user_id THEN ub.user_b ELSE ub.user_a END AS user_id,
      u.username,
      u.avatar_url,
      public.get_user_intimacy(
        p_user_id,
        CASE WHEN ub.user_a = p_user_id THEN ub.user_b ELSE ub.user_a END
      ) AS intimacy,
      GREATEST(0, (EXTRACT(EPOCH FROM (now() - ub.created_at)) / 86400)::integer) AS days,
      ub.created_at
    FROM public.user_buddies ub
    JOIN public.users u ON u.id = CASE WHEN ub.user_a = p_user_id THEN ub.user_b ELSE ub.user_a END
    WHERE ub.user_a = p_user_id OR ub.user_b = p_user_id
  ) t;

  v_count := public.count_user_close_friends(p_user_id);

  RETURN jsonb_build_object(
    'couple', v_couple,
    'buddies', v_buddies,
    'close_friends_count', v_count,
    'close_friends_limit', 6
  );
END;
$$;

-- Notifications for buddy invitations
CREATE OR REPLACE FUNCTION public.handle_buddy_invitation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inviter_name text;
  v_invitee_name text;
  v_tier_label text;
BEGIN
  SELECT COALESCE(username, 'User') INTO v_inviter_name FROM public.users WHERE id = NEW.inviter_id;
  SELECT COALESCE(username, 'User') INTO v_invitee_name FROM public.users WHERE id = NEW.invitee_id;
  v_tier_label := initcap(NEW.tier);

  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
    VALUES (
      NEW.invitee_id,
      format('%s Invitation', v_tier_label),
      format('%s invited you to become their %s. Tap to accept or decline.', v_inviter_name, v_tier_label),
      'buddy_invite',
      'friend',
      jsonb_build_object(
        'invitation_id', NEW.id,
        'tier', NEW.tier,
        'inviter_id', NEW.inviter_id
      )
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
    VALUES (
      NEW.inviter_id,
      format('%s Accepted', v_tier_label),
      format('%s accepted your %s invitation.', v_invitee_name, v_tier_label),
      'buddy_invite_accepted',
      'friend',
      jsonb_build_object(
        'invitation_id', NEW.id,
        'tier', NEW.tier,
        'invitee_id', NEW.invitee_id
      )
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'rejected' THEN
    INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
    VALUES (
      NEW.inviter_id,
      format('%s Declined', v_tier_label),
      format('%s declined your %s invitation.', v_invitee_name, v_tier_label),
      'buddy_invite_rejected',
      'friend',
      jsonb_build_object(
        'invitation_id', NEW.id,
        'tier', NEW.tier
      )
    );
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_buddy_invitation ON public.buddy_invitations;
CREATE TRIGGER on_buddy_invitation
  AFTER INSERT OR UPDATE OF status ON public.buddy_invitations
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_buddy_invitation();

GRANT EXECUTE ON FUNCTION public.get_user_intimacy(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_buddy_eligible(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.invite_buddy(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_buddy_invite(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_buddy(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_user_intimacy_board(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_user_close_friends(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.buddy_tier_threshold(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.are_mutual_followers(uuid, uuid) TO authenticated;
