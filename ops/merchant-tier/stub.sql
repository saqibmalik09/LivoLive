CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS auth._ctx (uid uuid, role text);
INSERT INTO auth._ctx VALUES (NULL, 'service_role');
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT uid FROM auth._ctx LIMIT 1 $$;
CREATE OR REPLACE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$ SELECT role FROM auth._ctx LIMIT 1 $$;

CREATE TABLE public.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text,
  short_id integer UNIQUE,
  avatar_url text,
  country_code text,
  coins bigint DEFAULT 0,
  reseller_coins bigint DEFAULT 0,
  is_reseller boolean DEFAULT false,
  is_banned boolean DEFAULT false,
  banned_at timestamptz,
  ban_reason text,
  updated_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  amount bigint NOT NULL,
  currency_type text,
  transaction_type text,
  reference_id uuid,
  created_at timestamptz DEFAULT now(),
  description text,
  CONSTRAINT transactions_currency_type_check CHECK (currency_type = ANY (ARRAY['coin','diamond','cash'])),
  CONSTRAINT transactions_transaction_type_check CHECK (transaction_type = ANY (ARRAY[
    'recharge','gift_sent','gift_received','lucky_gift_bonus','game_win','game_loss','withdrawal',
    'purchase','agency_commission','salary_payout','transfer_out','transfer_in','exchange',
    'rupee_game_entry','rupee_game_refund','lucky_pro_gift_bonus','room_reward','weekly_room_reward',
    'invite_register_bonus','invite_welcome_bonus','invite_milestone','invite_wheel',
    'invite_first_recharge','invite_recharge_bonus','task_checkin','task_wheel','task_reward',
    'cash_exchange_self','cash_exchange_other_out','cash_exchange_other_in','withdrawal_hold',
    'withdrawal_refund','real_name_deposit','seller_package']))
);

CREATE TABLE public.system_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text,
  content text,
  type text,
  icon_type text,
  metadata jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.coin_seller_policy_settings (
  id int PRIMARY KEY,
  coins_per_usd bigint,
  min_recharge_usd numeric,
  is_active boolean,
  updated_at timestamptz
);
INSERT INTO public.coin_seller_policy_settings VALUES (1, 111760, 1.00, true, now());
