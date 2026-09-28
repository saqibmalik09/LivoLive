-- Fix duplicate rooms on Party screen: one row per room (best daily/weekly/monthly rank).
CREATE OR REPLACE VIEW public.active_rooms_with_rankings AS
SELECT
  r.id,
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
  u.vip_level AS host_vip_level,
  COALESCE(vp.has_room_priority, false) AS has_room_priority,
  rr.rank AS current_rank,
  rr.score AS ranking_score,
  rr.ranking_type,
  ra.badge_url AS rank_badge,
  ra.frame_url AS rank_frame
FROM rooms r
LEFT JOIN users u ON r.host_id = u.id
LEFT JOIN vip_plans vp ON u.vip_level = vp.level
LEFT JOIN LATERAL (
  SELECT rank, score, ranking_type
  FROM room_rankings
  WHERE room_id = r.id
  ORDER BY
    CASE ranking_type
      WHEN 'daily' THEN 1
      WHEN 'weekly' THEN 2
      WHEN 'monthly' THEN 3
      ELSE 4
    END,
    rank ASC,
    score DESC
  LIMIT 1
) rr ON true
LEFT JOIN ranking_assets ra
  ON rr.rank = ra.rank_position
 AND rr.ranking_type = ra.ranking_type
WHERE r.is_active = true;
