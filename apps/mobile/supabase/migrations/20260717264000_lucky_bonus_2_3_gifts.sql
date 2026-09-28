-- Lucky / Lucky Pro: ensure 2–3 gifts → bonus, and fix send_gift bonus RPC call.

UPDATE public.lucky_gift_config SET
  is_enabled = true,
  gifts_for_bonus_min = 2,
  gifts_for_bonus_max = 3,
  bonus_chance_percent = 100,
  bonus_trigger_mode = 'both',
  cooldown_seconds = 0,
  min_gift_value_for_bonus = 0,
  updated_at = now()
WHERE id = 1;

UPDATE public.lucky_pro_gift_config SET
  is_enabled = true,
  gifts_for_bonus_min = 2,
  gifts_for_bonus_max = 3,
  bonus_chance_percent = 100,
  bonus_trigger_mode = 'both',
  cooldown_seconds = 0,
  min_gift_value_for_bonus = 0,
  updated_at = now()
WHERE id = 1;

-- Reset counters so the next 2–3 gifts can hit the threshold cleanly.
UPDATE public.lucky_gift_sender_counters SET gift_count = 0, next_bonus_at = 2;
UPDATE public.lucky_pro_gift_sender_counters SET gift_count = 0, next_bonus_at = 2;
UPDATE public.lucky_gift_counters SET gift_count = 0, next_bonus_at = 2;
UPDATE public.lucky_pro_gift_counters SET gift_count = 0, next_bonus_at = 2;
