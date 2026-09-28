-- Room lock: password stays in settings; is_locked toggled from tools sheet.

ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS is_locked boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.rooms.is_locked IS
  'When true, joiners (except host/admins) must enter room_password.';

COMMENT ON COLUMN public.rooms.room_password IS
  'Numeric room lock PIN set in room settings. Kept when unlocking.';

-- Existing passworded rooms start locked.
UPDATE public.rooms
SET is_locked = true
WHERE COALESCE(NULLIF(trim(room_password), ''), '') IS NOT NULL
  AND is_locked = false;

CREATE OR REPLACE FUNCTION public.verify_room_password(
  p_room_id uuid,
  p_password text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_host uuid;
  v_locked boolean;
  v_pass text;
BEGIN
  SELECT host_id, is_locked, room_password
  INTO v_host, v_locked, v_pass
  FROM public.rooms
  WHERE id = p_room_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Host always ok
  IF v_uid IS NOT NULL AND v_uid = v_host THEN
    RETURN true;
  END IF;

  -- Room admin / co-host bypass
  IF v_uid IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.room_members rm
    WHERE rm.room_id = p_room_id
      AND rm.user_id = v_uid
      AND COALESCE(rm.role, '') IN ('admin', 'co_host', 'host')
  ) THEN
    RETURN true;
  END IF;

  IF COALESCE(v_locked, false) = false THEN
    RETURN true;
  END IF;

  RETURN COALESCE(v_pass, '') <> ''
    AND COALESCE(v_pass, '') = COALESCE(trim(p_password), '');
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_room_password(uuid, text)
  TO authenticated, anon, service_role;

-- Expose is_locked on party/home list view.
DROP VIEW IF EXISTS public.active_rooms_with_rankings;

CREATE VIEW public.active_rooms_with_rankings AS
WITH room_daily_ranks AS (
  SELECT
    rs.room_id,
    RANK() OVER (
      ORDER BY rs.total_exp DESC NULLS LAST, rs.hotness_score DESC NULLS LAST
    )::int AS daily_rank,
    rs.total_exp AS ranking_score
  FROM public.room_stats rs
)
SELECT
  r.id,
  r.short_id,
  r.host_id,
  r.title,
  r.theme,
  r.is_active,
  r.room_password,
  r.is_locked,
  r.created_at,
  r.room_topic,
  r.image_url,
  r.announcement,
  r.country_code,
  r.is_private,
  r.decoration_id,
  r.membership_tag_name,
  r.membership_tag_color,
  r.mic_count,
  r.party_mode,
  r.background_url,
  r.youtube_state,
  r.online_users_count,
  r.chat_cleared_at,
  r.admin_only_chat,
  u.username AS host_name,
  u.avatar_url AS host_avatar,
  u.short_id AS host_short_id,
  u.vip_level AS host_vip_level,
  COALESCE(vp.has_room_priority, false) AS has_room_priority,
  dr.daily_rank AS current_rank,
  dr.ranking_score,
  'daily'::text AS ranking_type,
  ra.badge_url AS rank_badge,
  ra.frame_url AS rank_frame
FROM public.rooms r
LEFT JOIN public.users u ON r.host_id = u.id
LEFT JOIN public.vip_plans vp ON u.vip_level = vp.level
LEFT JOIN room_daily_ranks dr ON dr.room_id = r.id
LEFT JOIN public.ranking_assets ra
  ON dr.daily_rank = ra.rank_position
 AND ra.ranking_type = 'daily'
 AND ra.category = 'Room'
WHERE r.is_active = true;

GRANT SELECT ON public.active_rooms_with_rankings TO authenticated, anon;
