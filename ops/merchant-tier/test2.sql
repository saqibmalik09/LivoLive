\set ON_ERROR_STOP on
\pset pager off
UPDATE auth._ctx SET uid = NULL, role = 'service_role';

\echo '── A. reject the pending withdrawal → coins must come back ──'
SELECT admin_process_merchant_withdrawal(
  (SELECT id FROM merchant_withdrawals WHERE status='pending' LIMIT 1),
  'rejected', 'bank details invalid', '00000000-0000-0000-0000-0000000000a1')->>'message' AS result;
SELECT merchant_coins AS balance_after_refund FROM users WHERE short_id = 2001;

\echo '── B. block the merchant ──'
SELECT admin_block_merchant('00000000-0000-0000-0000-0000000000b1', true,
  'under review', '00000000-0000-0000-0000-0000000000a1')->>'message' AS result;

\echo '── C. a blocked merchant cannot supply or withdraw ──'
UPDATE auth._ctx SET uid = '00000000-0000-0000-0000-0000000000b1', role = 'authenticated';
SELECT merchant_recharge_reseller('00000000-0000-0000-0000-0000000000c2', 1000)->>'message' AS supply;
SELECT merchant_request_withdrawal(1000)->>'message' AS withdrawal;

\echo '── D. unblock, then supply works again ──'
UPDATE auth._ctx SET uid = NULL, role = 'service_role';
SELECT admin_block_merchant('00000000-0000-0000-0000-0000000000b1', false)->>'message' AS result;
UPDATE auth._ctx SET uid = '00000000-0000-0000-0000-0000000000b1', role = 'authenticated';
SELECT merchant_recharge_reseller('00000000-0000-0000-0000-0000000000c2', 50000, 'second seller')->>'message' AS result;

\echo '── E. a merchant cannot spend someone else''s wallet ──'
SELECT merchant_recharge_reseller('00000000-0000-0000-0000-0000000000c1', 1000, 'theft',
  '00000000-0000-0000-0000-0000000000a1')->>'message' AS result;

\echo '── F. a merchant cannot read another merchant''s books ──'
SELECT COALESCE(get_merchant_overview('00000000-0000-0000-0000-0000000000a1')->>'message','(rows)') AS result;
SELECT count(*) AS other_ledger_rows FROM get_merchant_ledger('00000000-0000-0000-0000-0000000000a1');

\echo '── G. admin list shows the figures ──'
UPDATE auth._ctx SET uid = NULL, role = 'service_role';
SELECT short_id, username, wallet_balance, total_sales, total_profit, total_deposited,
       seller_count, is_blocked FROM admin_list_merchants();

\echo '── H. revoking merchant while coins remain must refuse ──'
SELECT admin_set_merchant('00000000-0000-0000-0000-0000000000b1', false)->>'message' AS result;

\echo '── I. drain to zero, then revoke succeeds ──'
SELECT admin_adjust_merchant_coins('00000000-0000-0000-0000-0000000000b1',
  -(SELECT merchant_coins FROM users WHERE short_id=2001), 'closing out')->>'success' AS drained;
SELECT admin_set_merchant('00000000-0000-0000-0000-0000000000b1', false)->>'message' AS result;
SELECT is_merchant, merchant_coins FROM users WHERE short_id = 2001;

\echo '── J. non-admin cannot promote a merchant ──'
UPDATE auth._ctx SET uid = '00000000-0000-0000-0000-0000000000d1', role = 'authenticated';
SELECT admin_set_merchant('00000000-0000-0000-0000-0000000000d1', true)->>'message' AS result;
SELECT admin_adjust_merchant_coins('00000000-0000-0000-0000-0000000000b1', 999999)->>'message' AS result;
