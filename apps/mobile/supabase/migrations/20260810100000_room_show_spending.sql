-- Owner can toggle room spending UI (daily coins + seat gift badges).
ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS show_spending BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN public.rooms.show_spending IS
  'When true, show room spending icons (header daily coins + seat gift badges).';
