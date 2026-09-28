-- Rename level reward type card_frame -> entrance.

UPDATE public.wealth_level_assets
SET feature_key = 'entrance'
WHERE feature_key = 'card_frame';

UPDATE public.charm_level_assets
SET feature_key = 'entrance'
WHERE feature_key = 'card_frame';

ALTER TABLE public.wealth_level_assets
  DROP CONSTRAINT IF EXISTS wealth_level_assets_feature_key_check;

ALTER TABLE public.wealth_level_assets
  ADD CONSTRAINT wealth_level_assets_feature_key_check
  CHECK (feature_key IN ('frame', 'bubble', 'card_background', 'entrance'));

CREATE OR REPLACE FUNCTION public.grant_level_rewards(
  p_user_id uuid,
  p_kind text,
  p_new_level integer,
  p_old_level integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  lv integer;
  r record;
  v_expires timestamptz;
BEGIN
  IF p_new_level IS NULL OR p_old_level IS NULL OR p_new_level <= p_old_level THEN
    RETURN;
  END IF;

  FOR lv IN p_old_level + 1 .. p_new_level LOOP
    IF p_kind = 'wealth' THEN
      FOR r IN
        SELECT wla.shop_item_id, si.duration_days
        FROM public.wealth_level_assets wla
        JOIN public.shop_items si ON si.id = wla.shop_item_id
        WHERE wla.level = lv
          AND wla.shop_item_id IS NOT NULL
          AND si.is_active = TRUE
      LOOP
        v_expires := CASE
          WHEN COALESCE(r.duration_days, 0) > 0
            THEN NOW() + (r.duration_days || ' days')::interval
          ELSE '9999-12-31'::timestamptz
        END;

        INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
        VALUES (p_user_id, r.shop_item_id, 'level_reward', v_expires)
        ON CONFLICT (user_id, item_id) DO NOTHING;
      END LOOP;
    ELSIF p_kind = 'charm' THEN
      FOR r IN
        SELECT cla.shop_item_id, si.duration_days
        FROM public.charm_level_assets cla
        JOIN public.shop_items si ON si.id = cla.shop_item_id
        WHERE cla.level = lv
          AND cla.feature_key IN ('frame', 'bubble', 'card_background', 'entrance')
          AND cla.shop_item_id IS NOT NULL
          AND si.is_active = TRUE
      LOOP
        v_expires := CASE
          WHEN COALESCE(r.duration_days, 0) > 0
            THEN NOW() + (r.duration_days || ' days')::interval
          ELSE '9999-12-31'::timestamptz
        END;

        INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
        VALUES (p_user_id, r.shop_item_id, 'level_reward', v_expires)
        ON CONFLICT (user_id, item_id) DO NOTHING;
      END LOOP;
    END IF;
  END LOOP;
END;
$function$;
