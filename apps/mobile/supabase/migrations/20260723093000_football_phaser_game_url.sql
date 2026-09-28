-- Point Football Roulette (Bounty Football) at the Phaser hybrid shell.
-- Old React /football remains in the repo as rollback only.

update public.game_configs
set
  game_url = 'https://sk-live-games.vercel.app/football-phaser',
  icon_url = 'https://sk-live-games.vercel.app/game-icons/football_roulette_icon.png',
  is_active = true,
  updated_at = now()
where slug = 'football_roulette';
