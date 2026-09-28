-- Seed demo room reward pool from shop_items when empty (admin can edit later).

DO $$
DECLARE
  v_count integer;
  v_coin_url text;
  v_level integer;
  v_featured record;
  v_item record;
  v_amts integer[];
  v_amt integer;
  v_idx integer;
BEGIN
  SELECT COUNT(*)::int INTO v_count FROM public.room_reward_items;
  IF v_count > 0 THEN
    RETURN;
  END IF;

  SELECT image_url INTO v_coin_url
  FROM public.shop_items
  WHERE is_active = true
    AND image_url IS NOT NULL
    AND btrim(image_url) <> ''
  ORDER BY
    CASE WHEN lower(name) LIKE '%coin%' THEN 0 ELSE 1 END,
    price_coins ASC NULLS LAST
  LIMIT 1;

  IF v_coin_url IS NULL THEN
    RAISE NOTICE 'No shop images — skip room reward seed';
    RETURN;
  END IF;

  FOR v_level IN 1..5 LOOP
    v_amts := CASE v_level
      WHEN 1 THEN ARRAY[200, 300, 500]
      WHEN 2 THEN ARRAY[500, 800, 1000]
      WHEN 3 THEN ARRAY[1000, 1500, 2000]
      WHEN 4 THEN ARRAY[2000, 3000, 5000]
      ELSE ARRAY[5000, 8000, 10000]
    END;

    SELECT id, name, image_url
    INTO v_featured
    FROM public.shop_items
    WHERE is_active = true
      AND image_url IS NOT NULL
      AND btrim(image_url) <> ''
    ORDER BY price_coins ASC NULLS LAST
    OFFSET (v_level * 3)
    LIMIT 1;

    IF FOUND THEN
      INSERT INTO public.room_reward_items (
        level, title, image_url, reward_type, coin_amount, shop_item_id,
        weight, sort_order, is_active, is_featured
      ) VALUES (
        v_level, COALESCE(v_featured.name, 'Featured'), v_featured.image_url,
        'shop_item', 0, v_featured.id, 5, 0, true, true
      );
    ELSE
      INSERT INTO public.room_reward_items (
        level, title, image_url, reward_type, coin_amount, shop_item_id,
        weight, sort_order, is_active, is_featured
      ) VALUES (
        v_level, 'Featured Coins', v_coin_url, 'coins', v_amts[3], NULL,
        5, 0, true, true
      );
    END IF;

    FOREACH v_amt IN ARRAY v_amts LOOP
      v_idx := array_position(v_amts, v_amt);
      INSERT INTO public.room_reward_items (
        level, title, image_url, reward_type, coin_amount, shop_item_id,
        weight, sort_order, is_active, is_featured
      ) VALUES (
        v_level, v_amt || ' Coins', v_coin_url, 'coins', v_amt, NULL,
        GREATEST(5, 20 - (v_idx - 1) * 3), v_idx, true, false
      );
    END LOOP;

    FOR v_idx IN 0..2 LOOP
      SELECT id, name, image_url
      INTO v_item
      FROM public.shop_items
      WHERE is_active = true
        AND image_url IS NOT NULL
        AND btrim(image_url) <> ''
      ORDER BY price_coins ASC NULLS LAST
      OFFSET (v_level * 5 + v_idx + 1)
      LIMIT 1;

      IF FOUND THEN
        INSERT INTO public.room_reward_items (
          level, title, image_url, reward_type, coin_amount, shop_item_id,
          weight, sort_order, is_active, is_featured
        ) VALUES (
          v_level, COALESCE(v_item.name, 'Reward'), v_item.image_url,
          'shop_item', 0, v_item.id, 8, 10 + v_idx, true, false
        );
      END IF;
    END LOOP;
  END LOOP;
END $$;
