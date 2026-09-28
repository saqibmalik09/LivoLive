-- Profile tab promo carousel banners (separate from Home Hot top/mid-feed).

ALTER TABLE public.banners
  DROP CONSTRAINT IF EXISTS banners_placement_check;

ALTER TABLE public.banners
  ADD CONSTRAINT banners_placement_check
  CHECK (placement IN ('top', 'after_rooms', 'profile'));

COMMENT ON COLUMN public.banners.placement IS
  'Banner slot: top (Hot carousel), after_rooms (mid-feed), profile (Me tab promo).';

-- One-time seed: copy home top banners into profile if profile is empty.
INSERT INTO public.banners (image_url, link_url, priority, is_active, placement)
SELECT b.image_url, b.link_url, b.priority, b.is_active, 'profile'
FROM public.banners b
WHERE b.placement = 'top'
  AND NOT EXISTS (
    SELECT 1 FROM public.banners p WHERE p.placement = 'profile'
  );
