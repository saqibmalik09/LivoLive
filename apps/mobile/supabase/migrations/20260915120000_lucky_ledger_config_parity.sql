-- Allow 1x ladder steps (RaveStar parity) then align Lucky / Lucky Pro config.
-- Gateway ledger RTP is 85–90% (code/env); DB range must allow 1…500x.

ALTER TABLE public.lucky_gift_config
  DROP CONSTRAINT IF EXISTS lucky_bonus_mult_range;
ALTER TABLE public.lucky_gift_config
  ADD CONSTRAINT lucky_bonus_mult_range
  CHECK (bonus_multiplier_min >= 1 AND bonus_multiplier_max >= bonus_multiplier_min);

ALTER TABLE public.lucky_pro_gift_config
  DROP CONSTRAINT IF EXISTS lucky_pro_bonus_mult_range;
ALTER TABLE public.lucky_pro_gift_config
  ADD CONSTRAINT lucky_pro_bonus_mult_range
  CHECK (bonus_multiplier_min >= 1 AND bonus_multiplier_max >= bonus_multiplier_min);

UPDATE public.lucky_gift_config
SET
  receiver_percent = 5,
  bonus_multiplier_min = 1,
  bonus_multiplier_max = 500,
  max_bonus_coins_per_win = 1000000,
  max_daily_bonus_per_sender = NULL,
  max_daily_bonus_global = NULL,
  updated_at = now()
WHERE id = 1;

UPDATE public.lucky_pro_gift_config
SET
  receiver_percent = 5,
  bonus_multiplier_min = 1,
  bonus_multiplier_max = 500,
  max_bonus_coins_per_win = 2000000,
  max_daily_bonus_per_sender = NULL,
  max_daily_bonus_global = NULL,
  updated_at = now()
WHERE id = 1;
