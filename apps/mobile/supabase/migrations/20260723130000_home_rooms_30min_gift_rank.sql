-- Home Popular ranking: last 30 minutes gift coins inside each room.
-- ranking_score / current_rank on active_rooms_with_rankings drive list order.

DROP VIEW IF EXISTS public.active_rooms_with_rankings;

CREATE VIEW public.active_rooms_with_rankings AS
WITH recent_gifts AS (
  SELECT
    gl.room_id,
    COALESCE(SUM(gl.amount), 0)::bigint AS gift_score
  FROM public.gift_logs gl
  WHERE gl.room_id IS NOT NULL
    AND gl.created_at >= (now() - interval '30 minutes')
  GROUP BY gl.room_id
),
room_recent_ranks AS (
  SELECT
    r.id AS room_id,
    COALESCE(rg.gift_score, 0)::bigint AS ranking_score,
    RANK() OVER (
      ORDER BY COALESCE(rg.gift_score, 0) DESC,
               COALESCE(r.online_users_count, 0) DESC
    )::int AS recent_rank
  FROM public.rooms r
  LEFT JOIN recent_gifts rg ON rg.room_id = r.id
  WHERE r.is_active = true
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
  rr.recent_rank AS current_rank,
  rr.ranking_score,
  'daily'::text AS ranking_type,
  ra.badge_url AS rank_badge,
  ra.frame_url AS rank_frame
FROM public.rooms r
LEFT JOIN public.users u ON r.host_id = u.id
LEFT JOIN public.vip_plans vp ON u.vip_level = vp.level
LEFT JOIN room_recent_ranks rr ON rr.room_id = r.id
LEFT JOIN public.ranking_assets ra
  ON rr.recent_rank = ra.rank_position
 AND ra.ranking_type = 'daily'
 AND ra.category = 'Room'
WHERE r.is_active = true;

GRANT SELECT ON public.active_rooms_with_rankings TO authenticated, anon;

-- Card heart badge: gift coins in the last N minutes (default 30).
CREATE OR REPLACE FUNCTION public.get_rooms_recent_gift_totals(
  p_room_ids uuid[],
  p_minutes integer DEFAULT 30
)
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
    AND gl.created_at >= (now() - make_interval(mins => GREATEST(COALESCE(p_minutes, 30), 1)))
  GROUP BY gl.room_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_rooms_recent_gift_totals(uuid[], integer)
  TO anon, authenticated, service_role;
