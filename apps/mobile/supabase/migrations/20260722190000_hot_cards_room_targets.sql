-- Pin Party Star / Music hot cards to specific rooms (admin-configurable).
ALTER TABLE public.home_hot_cards_config
  ADD COLUMN IF NOT EXISTS party_card_room_id uuid REFERENCES public.rooms(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS music_card_room_id uuid REFERENCES public.rooms(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.home_hot_cards_config.party_card_room_id IS
  'Room opened when user taps Party Star hot card';
COMMENT ON COLUMN public.home_hot_cards_config.music_card_room_id IS
  'Room opened when user taps Music hot card';
