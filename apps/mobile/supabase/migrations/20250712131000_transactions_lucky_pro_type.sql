-- Allow Lucky / Lucky Pro bonus transaction types.

ALTER TABLE public.transactions
  DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;

ALTER TABLE public.transactions
  ADD CONSTRAINT transactions_transaction_type_check
  CHECK (transaction_type = ANY (ARRAY['recharge'::text, 'gift_sent'::text, 'gift_received'::text, 'lucky_gift_bonus'::text, 'game_win'::text, 'game_loss'::text, 'withdrawal'::text, 'purchase'::text, 'agency_commission'::text, 'salary_payout'::text, 'transfer_out'::text, 'transfer_in'::text, 'exchange'::text, 'rupee_game_entry'::text, 'rupee_game_refund'::text, 'lucky_pro_gift_bonus'::text]));
