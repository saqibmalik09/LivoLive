\set ON_ERROR_STOP on
\pset pager off
-- actors
INSERT INTO users (id, username, short_id) VALUES
  ('00000000-0000-0000-0000-0000000000a1','AdminBoss', 1001),
  ('00000000-0000-0000-0000-0000000000b1','MerchantOne', 2001),
  ('00000000-0000-0000-0000-0000000000c1','SellerAlpha', 3001),
  ('00000000-0000-0000-0000-0000000000c2','SellerBeta', 3002),
  ('00000000-0000-0000-0000-0000000000d1','PlainUser', 4001);
UPDATE users SET is_reseller = true WHERE short_id IN (3001, 3002);

\echo '── 1. promote any ID to merchant (admin) ──'
SELECT admin_set_merchant('00000000-0000-0000-0000-0000000000b1', true, 10, 111760, 0,
       'Merchant One', '+92300', 'first merchant', '00000000-0000-0000-0000-0000000000a1')->>'message' AS result;

\echo '── 2. recharge merchant +1,000,000 ──'
SELECT admin_adjust_merchant_coins('00000000-0000-0000-0000-0000000000b1', 1000000, 'opening float',
       '00000000-0000-0000-0000-0000000000a1')::text AS result;

\echo '── 3. remove 200,000 ──'
SELECT admin_adjust_merchant_coins('00000000-0000-0000-0000-0000000000b1', -200000, 'correction',
       '00000000-0000-0000-0000-0000000000a1')::text AS result;

\echo '── 4. over-deduct must fail ──'
SELECT admin_adjust_merchant_coins('00000000-0000-0000-0000-0000000000b1', -99999999, 'too much',
       '00000000-0000-0000-0000-0000000000a1')->>'message' AS result;

-- become the merchant
UPDATE auth._ctx SET uid = '00000000-0000-0000-0000-0000000000b1', role = 'authenticated';

\echo '── 5. merchant searches a coin seller by ID ──'
SELECT short_id, username, reseller_coins, is_mine FROM merchant_search_coin_sellers('3001');

\echo '── 6. merchant supplies the seller 300,000 (10% commission) ──'
SELECT merchant_recharge_reseller('00000000-0000-0000-0000-0000000000c1', 300000, 'first supply')::text AS result;

\echo '── 7. balances moved correctly ──'
SELECT username, merchant_coins, reseller_coins, merchant_id IS NOT NULL AS linked
FROM users WHERE short_id IN (2001, 3001) ORDER BY short_id;

\echo '── 8. seller sees it in the ledger the app already reads ──'
SELECT transaction_type, amount, description FROM transactions
WHERE user_id = '00000000-0000-0000-0000-0000000000c1';

\echo '── 9. supplying a non-seller must fail ──'
SELECT merchant_recharge_reseller('00000000-0000-0000-0000-0000000000d1', 1000)->>'message' AS result;

\echo '── 10. overspending must fail ──'
SELECT merchant_recharge_reseller('00000000-0000-0000-0000-0000000000c2', 99999999)->>'message' AS result;

\echo '── 11. overview figures ──'
SELECT jsonb_pretty(jsonb_build_object(
  'balance', o->'wallet_balance', 'sales', o->'total_sales', 'profit', o->'total_profit',
  'deposited', o->'total_deposited', 'deducted', o->'total_deducted',
  'sellers', o->'seller_count', 'sales_usd', o->'sales_usd', 'profit_usd', o->'profit_usd'))
FROM (SELECT get_merchant_overview()::jsonb AS o) q;

\echo '── 12. merchant resellers list ──'
SELECT short_id, username, total_supplied, supply_count, is_linked FROM get_merchant_resellers();

\echo '── 13. withdrawal request holds the coins ──'
SELECT merchant_request_withdrawal(100000, 'bank', 'ACC-123', 'monthly payout')->>'message' AS result;
SELECT merchant_coins FROM users WHERE short_id = 2001;

\echo '── 14. ledger (merchant transaction history) ──'
SELECT entry_type, amount, direction, balance_after, profit_coins, counterparty_sid
FROM get_merchant_ledger() ORDER BY created_at;
