-- Activate Greedy King Phaser shell in room bottom sheet.
update public.game_configs
set
  game_url = 'https://sk-live-games.vercel.app/greedy-phaser',
  icon_url = 'https://sk-live-games.vercel.app/game-icons/greedy_king_icon.png',
  is_active = true,
  updated_at = now()
where slug = 'greedy_king';

-- Hide legacy hyphen slug duplicate if present.
update public.game_configs
set
  is_active = false,
  updated_at = now()
where slug = 'greedy-king';
