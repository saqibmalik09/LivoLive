-- Level reward assets: admin assigns shop items per wealth/charm level.
-- Badge uploads stay on level_configs (wealth) and charm_level_assets (badge).

CREATE TABLE IF NOT EXISTS public.wealth_level_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  level integer NOT NULL,
  feature_key text NOT NULL CHECK (
    feature_key IN ('frame', 'bubble', 'card_background', 'card_frame')
  ),
  shop_item_id uuid NOT NULL REFERENCES public.shop_items(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (level, feature_key)
);

CREATE INDEX IF NOT EXISTS idx_wealth_level_assets_level
  ON public.wealth_level_assets (level);

ALTER TABLE public.charm_level_assets
  ADD COLUMN IF NOT EXISTS shop_item_id uuid REFERENCES public.shop_items(id) ON DELETE SET NULL;

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
          AND cla.feature_key IN ('frame', 'bubble', 'card_background', 'card_frame')
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

CREATE OR REPLACE FUNCTION public.trigger_grant_level_rewards()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
BEGIN
  IF NEW.wealth_level IS DISTINCT FROM OLD.wealth_level
     AND COALESCE(NEW.wealth_level, 0) > COALESCE(OLD.wealth_level, 0) THEN
    PERFORM public.grant_level_rewards(
      NEW.id,
      'wealth',
      NEW.wealth_level,
      OLD.wealth_level
    );
  END IF;

  IF NEW.charm_level IS DISTINCT FROM OLD.charm_level
     AND COALESCE(NEW.charm_level, 0) > COALESCE(OLD.charm_level, 0) THEN
    PERFORM public.grant_level_rewards(
      NEW.id,
      'charm',
      NEW.charm_level,
      OLD.charm_level
    );
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS users_level_reward_trigger ON public.users;

CREATE TRIGGER users_level_reward_trigger
  AFTER UPDATE OF wealth_level, charm_level ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_grant_level_rewards();
