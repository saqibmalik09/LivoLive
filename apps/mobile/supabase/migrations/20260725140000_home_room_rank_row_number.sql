-- Exactly one room per rank (no RANK() ties → many rooms with frame 1).
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
    ROW_NUMBER() OVER (
      ORDER BY COALESCE(rg.gift_score, 0) DESC,
               COALESCE(r.online_users_count, 0) DESC,
               r.created_at ASC,
               r.id ASC
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
