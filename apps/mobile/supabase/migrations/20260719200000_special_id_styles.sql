-- Special / good-number UID styles (SVGA bubble + level colors).

CREATE TABLE IF NOT EXISTS public.special_id_styles (
  level smallint PRIMARY KEY CHECK (level BETWEEN 1 AND 9),
  name text NOT NULL,
  svga_url text NOT NULL DEFAULT '',
  primary_color text NOT NULL DEFAULT '#FFD54F',
  secondary_color text NOT NULL DEFAULT '#FF8F00',
  is_active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS special_id_level smallint
    REFERENCES public.special_id_styles(level)
    ON DELETE SET NULL;

COMMENT ON COLUMN public.users.special_id_level IS
  'Equipped good-number UID style (1-9). NULL = plain ID badge.';

INSERT INTO public.special_id_styles (level, name, primary_color, secondary_color)
VALUES
  (1, 'Bronze',   '#CD7F32', '#8B4513'),
  (2, 'Silver',   '#E8E8E8', '#9E9E9E'),
  (3, 'Gold',     '#FFD700', '#FF8F00'),
  (4, 'Emerald',  '#00E676', '#00695C'),
  (5, 'Sapphire', '#40C4FF', '#1565C0'),
  (6, 'Amethyst', '#E040FB', '#6A1B9A'),
  (7, 'Rose',     '#FF80AB', '#C2185B'),
  (8, 'Ruby',     '#FF5252', '#B71C1C'),
  (9, 'Diamond',  '#B2EBF2', '#FFD54F')
ON CONFLICT (level) DO UPDATE SET
  name = EXCLUDED.name,
  primary_color = EXCLUDED.primary_color,
  secondary_color = EXCLUDED.secondary_color,
  updated_at = now();

ALTER TABLE public.special_id_styles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read special id styles" ON public.special_id_styles;
CREATE POLICY "Anyone can read special id styles"
  ON public.special_id_styles FOR SELECT
  TO authenticated, anon
  USING (is_active = true);

GRANT SELECT ON public.special_id_styles TO authenticated, anon;
GRANT ALL ON public.special_id_styles TO service_role;

-- Admin assigns style + optional custom short_id in one call.
CREATE OR REPLACE FUNCTION public.admin_set_user_special_id(
  p_user_id uuid,
  p_level smallint DEFAULT NULL,
  p_short_id bigint DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF p_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'user_id required');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  IF p_level IS NOT NULL AND p_level <> 0 THEN
    IF p_level < 1 OR p_level > 9 THEN
      RETURN json_build_object('success', false, 'message', 'Level must be 1-9 or 0 to clear');
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.special_id_styles WHERE level = p_level AND is_active
    ) THEN
      RETURN json_build_object('success', false, 'message', 'Style level not found');
    END IF;
  END IF;

  IF p_short_id IS NOT NULL THEN
    IF p_short_id < 1 THEN
      RETURN json_build_object('success', false, 'message', 'Invalid short_id');
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.users
      WHERE short_id = p_short_id AND id IS DISTINCT FROM p_user_id
    ) THEN
      RETURN json_build_object('success', false, 'message', 'That ID is already taken');
    END IF;
  END IF;

  UPDATE public.users
  SET
    special_id_level = CASE
      WHEN p_level IS NULL THEN special_id_level
      WHEN p_level = 0 THEN NULL
      ELSE p_level
    END,
    short_id = COALESCE(p_short_id, short_id),
    updated_at = now()
  WHERE id = p_user_id;

  SELECT * INTO v_user FROM public.users WHERE id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Special ID updated',
    'short_id', v_user.short_id,
    'special_id_level', v_user.special_id_level
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_set_user_special_id(uuid, smallint, bigint) TO service_role;
