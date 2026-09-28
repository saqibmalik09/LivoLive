-- Fix wallet recharge Play IDs / inverted 1L vs 1.5L prices.
UPDATE public.recharge_packages
SET play_store_id = 'coins_1lakh'
WHERE play_store_id = 'coins_1200';

UPDATE public.recharge_packages
SET price_usd = 7.50
WHERE beans_amount = 100000
  AND play_store_id = 'coins_1lakh';

UPDATE public.recharge_packages
SET price_usd = 9.50
WHERE beans_amount = 150000
  AND play_store_id = 'coins_1.5lakh';
