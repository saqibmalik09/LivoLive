-- Social/inbox hot-path indexes for room_members, room_seats, users discovery sort.
-- Apply CONCURRENTLY in production via sklive-scripts/apply_room_social_indexes.js

CREATE INDEX IF NOT EXISTS room_members_user_id_idx ON public.room_members (user_id);
CREATE INDEX IF NOT EXISTS room_members_room_id_idx ON public.room_members (room_id);
CREATE INDEX IF NOT EXISTS room_seats_user_id_idx ON public.room_seats (user_id);
CREATE INDEX IF NOT EXISTS users_updated_at_idx ON public.users (updated_at DESC);
