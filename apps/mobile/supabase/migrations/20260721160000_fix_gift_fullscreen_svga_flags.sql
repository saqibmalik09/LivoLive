-- Gifts with SVGA media should play full-screen animation in rooms.

UPDATE public.shop_items
SET svga_url = image_url
WHERE is_gift = true
  AND is_active = true
  AND (svga_url IS NULL OR btrim(svga_url) = '')
  AND image_url ILIKE '%.svga';

UPDATE public.shop_items
SET is_full_screen = true
WHERE is_gift = true
  AND is_active = true
  AND is_full_screen = false
  AND (
    (svga_url IS NOT NULL AND btrim(svga_url) <> '')
    OR (image_url ILIKE '%.svga')
  );
