-- Remove duplicate Pizza Game from room bottom sheet; keep Big Eater only.
-- Both previously pointed at the same /pizza URL.

update public.game_configs
set
  is_active = false,
  updated_at = now()
where slug = 'pizza';

update public.game_configs
set
  is_active = true,
  updated_at = now()
where slug = 'pizza_express';
