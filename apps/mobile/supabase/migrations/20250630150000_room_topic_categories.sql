-- Repurpose room_topic as fixed category slug for Room tab filtering.

UPDATE public.rooms SET room_topic = CASE
  WHEN lower(coalesce(room_topic, '')) LIKE '%party%' THEN 'party'
  WHEN lower(coalesce(room_topic, '')) LIKE '%sing%'
    OR lower(coalesce(room_topic, '')) LIKE '%music%' THEN 'sing'
  WHEN lower(coalesce(room_topic, '')) LIKE '%dj%' THEN 'dj'
  WHEN lower(coalesce(room_topic, '')) LIKE '%poet%' THEN 'poetry'
  WHEN lower(coalesce(room_topic, '')) LIKE '%game%' THEN 'game'
  WHEN lower(coalesce(room_topic, '')) LIKE '%secret%' THEN 'secret'
  ELSE 'chat'
END;

ALTER TABLE public.rooms
  ALTER COLUMN room_topic SET DEFAULT 'chat';

ALTER TABLE public.rooms
  DROP CONSTRAINT IF EXISTS rooms_room_topic_category_check;

ALTER TABLE public.rooms
  ADD CONSTRAINT rooms_room_topic_category_check
  CHECK (room_topic IN ('chat', 'party', 'sing', 'dj', 'poetry', 'game', 'secret'));
