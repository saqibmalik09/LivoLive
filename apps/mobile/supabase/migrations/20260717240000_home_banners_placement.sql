-- Mid-feed home banners (after 4 room cards), separate from top carousel.

ALTER TABLE public.banners
  ADD COLUMN IF NOT EXISTS placement text NOT NULL DEFAULT 'top';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'banners_placement_check'
  ) THEN
    ALTER TABLE public.banners
      ADD CONSTRAINT banners_placement_check
      CHECK (placement IN ('top', 'after_rooms'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_banners_placement_active_priority
  ON public.banners (placement, is_active, priority DESC);

COMMENT ON COLUMN public.banners.placement IS
  'top = Home Hot top carousel; after_rooms = banner after first 4 room cards';
