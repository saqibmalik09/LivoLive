-- Default lucky gift percentage / bonus ranges (idempotent)
INSERT INTO public.lucky_gift_config (
  id,
  receiver_percent,
  gifts_for_bonus_min,
  gifts_for_bonus_max,
  bonus_multiplier_min,
  bonus_multiplier_max,
  bonus_chance_percent,
  bonus_trigger_mode,
  updated_at
)
VALUES (
  1,
  4,
  3,
  4,
  1.5,
  8,
  100,
  'both',
  now()
)
ON CONFLICT (id) DO UPDATE SET
  receiver_percent = EXCLUDED.receiver_percent,
  gifts_for_bonus_min = EXCLUDED.gifts_for_bonus_min,
  gifts_for_bonus_max = EXCLUDED.gifts_for_bonus_max,
  bonus_multiplier_min = EXCLUDED.bonus_multiplier_min,
  bonus_multiplier_max = EXCLUDED.bonus_multiplier_max,
  bonus_chance_percent = EXCLUDED.bonus_chance_percent,
  bonus_trigger_mode = EXCLUDED.bonus_trigger_mode,
  updated_at = now();
