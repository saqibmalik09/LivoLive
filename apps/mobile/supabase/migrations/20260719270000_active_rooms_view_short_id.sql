-- Expose rooms.short_id (same as host user ID) on home/party room lists.

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
