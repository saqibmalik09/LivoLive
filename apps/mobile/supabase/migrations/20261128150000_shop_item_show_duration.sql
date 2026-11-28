-- How long every viewer holds a sent gift in the centre of the room before it
-- flies to the receivers. 0 = the animation's own length (3 s for a gift with
-- no SVGA). Set per gift on the dashboard's shop item page.
ALTER TABLE public.shop_items
  ADD COLUMN IF NOT EXISTS show_duration_ms INTEGER NOT NULL DEFAULT 5000;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'shop_items_show_duration_ck'
  ) THEN
    ALTER TABLE public.shop_items
      ADD CONSTRAINT shop_items_show_duration_ck
      CHECK (show_duration_ms >= 0 AND show_duration_ms <= 60000);
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
