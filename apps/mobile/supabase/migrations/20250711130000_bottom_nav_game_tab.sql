-- Bottom nav: add 5th tab key 'game' for Rupee Game screen.

ALTER TABLE public.bottom_nav_items
  DROP CONSTRAINT IF EXISTS bottom_nav_items_nav_key_check;

ALTER TABLE public.bottom_nav_items
  ADD CONSTRAINT bottom_nav_items_nav_key_check
  CHECK (nav_key IN ('home', 'party', 'game', 'message', 'my'));

INSERT INTO public.bottom_nav_items (nav_key, label, icon_url, sort_order, is_active)
VALUES ('game', 'Game', '', 2, true)
ON CONFLICT (nav_key) DO UPDATE SET
  label = EXCLUDED.label,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;

-- Bump message/my sort order if they were 2/3
UPDATE public.bottom_nav_items SET sort_order = 3 WHERE nav_key = 'message';
UPDATE public.bottom_nav_items SET sort_order = 4 WHERE nav_key = 'my';
