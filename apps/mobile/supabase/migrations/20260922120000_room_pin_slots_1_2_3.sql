-- Normalize room pins to Rave-style slots 1 / 2 / 3 (unique).

-- Remap any existing timestamp-style pin_order values into 1..3 by recency.
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (ORDER BY pin_order DESC, created_at ASC) AS slot
  FROM public.rooms
  WHERE is_pinned = true
)
UPDATE public.rooms r
SET
  pin_order = CASE WHEN ranked.slot BETWEEN 1 AND 3 THEN ranked.slot ELSE 0 END,
  is_pinned = ranked.slot BETWEEN 1 AND 3
FROM ranked
WHERE r.id = ranked.id;

-- Unpin anything beyond slot 3.
UPDATE public.rooms
SET is_pinned = false, pin_order = 0
WHERE is_pinned = true AND (pin_order < 1 OR pin_order > 3);

DROP INDEX IF EXISTS public.rooms_pinned_order_idx;

CREATE UNIQUE INDEX IF NOT EXISTS rooms_pin_slot_unique_idx
  ON public.rooms (pin_order)
  WHERE is_pinned = true AND pin_order BETWEEN 1 AND 3;
