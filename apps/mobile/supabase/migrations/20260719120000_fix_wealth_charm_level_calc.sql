-- Fix wealth/charm level calculation to match admin-configured tables.
-- Bug: send_gift/purchase_shop_item used level_configs category 'wealth' (max ~11.6M for LV100)
-- and non-existent category 'charm', while admin edits 'user_wealth' (~21B for LV100)
-- and charm_level_configs.

CREATE OR REPLACE FUNCTION public.calc_wealth_level(p_value bigint)
RETURNS integer
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (
      SELECT level
      FROM public.level_configs
      WHERE category = 'user_wealth'
        AND min_exp <= COALESCE(p_value, 0)
      ORDER BY level DESC
      LIMIT 1
    ),
    1
  );
$$;

CREATE OR REPLACE FUNCTION public.calc_charm_level(p_value bigint)
RETURNS integer
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (
      SELECT level
      FROM public.charm_level_configs
      WHERE min_exp <= COALESCE(p_value, 0)
      ORDER BY level DESC
      LIMIT 1
    ),
    1
  );
$$;

-- Patch send_gift + purchase_shop_item level lookups (replace wrong categories)
DO $$
DECLARE
  r RECORD;
  def text;
  new_def text;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND p.proname IN ('send_gift', 'purchase_shop_item')
  LOOP
    def := pg_get_functiondef(r.oid);
    new_def := def;

    -- Wealth: admin table is user_wealth
    new_def := replace(new_def, 'category = ''wealth''', 'category = ''user_wealth''');

    -- Charm: use charm_level_configs instead of missing level_configs category 'charm'
    new_def := regexp_replace(
      new_def,
      'SELECT level INTO v_new_charm_level FROM public\.level_configs\s+WHERE category = ''charm'' AND min_exp <= v_new_charm_value ORDER BY level DESC LIMIT 1;',
      'SELECT level INTO v_new_charm_level FROM public.charm_level_configs WHERE min_exp <= v_new_charm_value ORDER BY level DESC LIMIT 1;',
      'g'
    );

    -- Prefer helper functions if still using old inline pattern after replace
    new_def := regexp_replace(
      new_def,
      'SELECT level INTO v_new_wealth_level FROM public\.level_configs\s+WHERE category = ''user_wealth'' AND min_exp <= v_new_wealth_value ORDER BY level DESC LIMIT 1;\s*IF v_new_wealth_level IS NULL THEN v_new_wealth_level := 1; END IF;',
      'v_new_wealth_level := public.calc_wealth_level(v_new_wealth_value);',
      'g'
    );
    new_def := regexp_replace(
      new_def,
      'SELECT level INTO v_new_charm_level FROM public\.charm_level_configs WHERE min_exp <= v_new_charm_value ORDER BY level DESC LIMIT 1;\s*IF v_new_charm_level IS NULL THEN v_new_charm_level := 1; END IF;',
      'v_new_charm_level := public.calc_charm_level(v_new_charm_value);',
      'g'
    );

    IF new_def IS DISTINCT FROM def THEN
      EXECUTE new_def;
      RAISE NOTICE 'Patched %', r.proname;
    ELSE
      RAISE NOTICE 'No text change for %', r.proname;
    END IF;
  END LOOP;
END $$;

-- Recalculate all user levels from correct config tables
UPDATE public.users u
SET
  wealth_level = public.calc_wealth_level(u.wealth_value),
  charm_level = public.calc_charm_level(u.charm_value),
  updated_at = now()
WHERE TRUE;
