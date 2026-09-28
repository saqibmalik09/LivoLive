-- Point all game webview URLs at SK Live games host (not rave-game).
UPDATE public.game_configs
SET
  game_url = replace(game_url, 'https://rave-game.vercel.app', 'https://sk-live-games.vercel.app'),
  icon_url = replace(icon_url, 'https://rave-game.vercel.app', 'https://sk-live-games.vercel.app')
WHERE game_url LIKE '%rave-game.vercel.app%'
   OR icon_url LIKE '%rave-game.vercel.app%';
