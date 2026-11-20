import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/features/merchant/providers/merchant_provider.dart';

/// The merchant panel — wholesale tier above coin sellers.
///
/// Admin → **Merchant** → Coin Seller → User. A merchant holds stock in
/// `merchant_coins` and supplies coin sellers, who in turn sell to users.
class MerchantScreen extends ConsumerStatefulWidget {
  const MerchantScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<MerchantScreen> createState() => _MerchantScreenState();
}

class _MerchantScreenState extends ConsumerState<MerchantScreen> {
  static const _tabs = ['Overview', 'Recharge', 'Sellers', 'History'];

  final _searchController = TextEditingController();
  final _amountController = TextEditingController();

  late int _tab;
  String _searchQuery = '';
  Map<String, dynamic>? _selectedSeller;
  String? _ledgerFilter;
  bool _busy = false;
  /// Recharge tab target: coin seller (stock to resell) or a user's own balance.
  bool _toUser = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, _tabs.length - 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ── actions ──────────────────────────────────────────────────────

  /// Top up a normal account's spendable balance (not seller stock).
  Future<void> _rechargeUser(int amount, Map<String, dynamic> user) async {
    setState(() => _busy = true);
    try {
      final res = await Supabase.instance.client.rpc(
        'merchant_recharge_user',
        params: {
          'p_user_id': user['id'],
          'p_amount': amount,
          'p_note': null,
        },
      );
      final map = res is Map ? Map<String, dynamic>.from(res) : null;
      final ok = map?['success'] == true;
      if (!mounted) return;
      if (ok) {
        _amountController.clear();
        setState(() {
          _selectedSeller = null;
          _searchQuery = '';
          _searchController.clear();
        });
        invalidateMerchantData(ref);
        ref.invalidate(userProfileProvider);
        _resultDialog(
          ok: true,
          title: 'Coins Sent',
          message:
              '${map?['message'] ?? 'Sent'}\n\nProfit on this sale: '
              '${NumberFormatter.format((map?['profit_coins'] as num?)?.toInt() ?? 0)} coins',
        );
      } else {
        _resultDialog(
          ok: false,
          title: 'Recharge Failed',
          message: map?['message']?.toString() ?? 'An error occurred',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _resultDialog(ok: false, title: 'Recharge Error', message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rechargeSeller(int amount, Map<String, dynamic> seller) async {
    setState(() => _busy = true);
    try {
      final res = await Supabase.instance.client.rpc(
        'merchant_recharge_reseller',
        params: {
          'p_reseller_id': seller['id'],
          'p_amount': amount,
          'p_note': null,
        },
      );
      final map = res is Map ? Map<String, dynamic>.from(res) : null;
      final ok = map?['success'] == true;
      if (!mounted) return;

      if (ok) {
        _amountController.clear();
        setState(() {
          _selectedSeller = null;
          _searchQuery = '';
          _searchController.clear();
        });
        invalidateMerchantData(ref);
        ref.invalidate(userProfileProvider);
        _resultDialog(
          ok: true,
          title: 'Recharge Sent',
          message:
              '${map?['message'] ?? 'Sent'}\n\nProfit on this sale: '
              '${NumberFormatter.format((map?['profit_coins'] as num?)?.toInt() ?? 0)} coins',
        );
      } else {
        _resultDialog(
          ok: false,
          title: 'Recharge Failed',
          message: map?['message']?.toString() ?? 'An error occurred',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _resultDialog(ok: false, title: 'Recharge Error', message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestWithdrawal(
    int amount,
    String method,
    String details,
  ) async {
    setState(() => _busy = true);
    try {
      final res = await Supabase.instance.client.rpc(
        'merchant_request_withdrawal',
        params: {
          'p_amount': amount,
          'p_method': method.isEmpty ? null : method,
          'p_details': details.isEmpty ? null : details,
        },
      );
      final map = res is Map ? Map<String, dynamic>.from(res) : null;
      final ok = map?['success'] == true;
      if (!mounted) return;
      if (ok) invalidateMerchantData(ref);
      _resultDialog(
        ok: ok,
        title: ok ? 'Withdrawal Requested' : 'Withdrawal Failed',
        message: map?['message']?.toString() ?? 'An error occurred',
      );
    } catch (e) {
      if (!mounted) return;
      _resultDialog(
        ok: false,
        title: 'Withdrawal Error',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── dialogs ──────────────────────────────────────────────────────

  void _resultDialog({
    required bool ok,
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              ok ? Iconsax.tick_circle : Iconsax.close_circle,
              color: ok ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: ok ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRecharge(int amount, Map<String, dynamic> seller) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Confirm Recharge',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Send ${NumberFormatter.format(amount)} coins to '
          '${seller['username'] ?? 'Account'} (ID ${seller['short_id'] ?? '—'})?'
          '\n\n${_toUser ? 'Goes straight to their own balance to spend.' : 'Goes to their seller stock to resell.'}'
          '\nDeducted from your merchant wallet.',
          style: const TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context);
              if (_toUser) {
                _rechargeUser(amount, seller);
              } else {
                _rechargeSeller(amount, seller);
              }
            },
            child: const Text(
              'Send',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _withdrawalSheet(int balance) {
    final amountCtl = TextEditingController();
    final methodCtl = TextEditingController();
    final detailsCtl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Withdrawal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Available: ${NumberFormatter.format(balance)} coins',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _sheetField(amountCtl, 'Amount in coins', numeric: true),
            const SizedBox(height: 12),
            _sheetField(methodCtl, 'Payout method (bank, easypaisa…)'),
            const SizedBox(height: 12),
            _sheetField(detailsCtl, 'Account number / details'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  final amt = int.tryParse(amountCtl.text.trim()) ?? 0;
                  if (amt <= 0 || amt > balance) {
                    Navigator.pop(ctx);
                    _resultDialog(
                      ok: false,
                      title: 'Invalid Amount',
                      message: amt <= 0
                          ? 'Enter an amount greater than zero.'
                          : 'You only hold ${NumberFormatter.format(balance)} coins.',
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  _requestWithdrawal(
                    amt,
                    methodCtl.text.trim(),
                    detailsCtl.text.trim(),
                  );
                },
                child: const Text(
                  'Submit Request',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetField(
    TextEditingController c,
    String hint, {
    bool numeric = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ── build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(merchantOverviewProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'Merchant Panel',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => invalidateMerchantData(ref),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              AppColors.primary.withOpacity(0.12),
              const Color(0xFF0F0F1A),
            ],
          ),
        ),
        child: overviewAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(
            child: asyncErrorWidget(
              e,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          data: (overview) {
            if (overview == null || overview['success'] != true) {
              return _notAMerchant(overview?['message']?.toString());
            }
            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: kToolbarHeight - 24),
                  if (overview['is_blocked'] == true)
                    _blockedBanner(overview['blocked_reason']?.toString()),
                  _tabBar(),
                  Expanded(child: _tabBody(overview)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _notAMerchant(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.shop, color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            Text(
              message ?? 'This account is not a merchant.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blockedBanner(String? reason) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.info_circle, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason == null || reason.isEmpty
                  ? 'Your merchant account is blocked. Contact admin.'
                  : 'Blocked: $reason',
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final active = _tab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: active ? Colors.black : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _tabBody(Map<String, dynamic> o) {
    switch (_tab) {
      case 1:
        return _rechargeTab(o);
      case 2:
        return _sellersTab();
      case 3:
        return _historyTab();
      default:
        return _overviewTab(o);
    }
  }

  // ── tab 0: overview ──────────────────────────────────────────────

  Widget _overviewTab(Map<String, dynamic> o) {
    int n(String k) => (o[k] as num?)?.toInt() ?? 0;
    final balance = n('wallet_balance');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.3),
                  AppColors.accent.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MERCHANT WALLET',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Iconsax.coin,
                        color: AppColors.gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        NumberFormatter.format(balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (n('coins_per_usd') > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '≈ \$${o['balance_usd'] ?? 0}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.12),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed:
                        _busy || balance <= 0 || o['is_blocked'] == true
                        ? null
                        : () => _withdrawalSheet(balance),
                    icon: const Icon(Iconsax.money_send, size: 18),
                    label: const Text(
                      'Request Withdrawal',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _statCard(
                'Total Sales',
                NumberFormatter.format(n('total_sales')),
                Iconsax.chart_success,
                AppColors.primary,
                sub: n('coins_per_usd') > 0 ? '\$${o['sales_usd'] ?? 0}' : null,
              ),
              const SizedBox(width: 12),
              _statCard(
                'Total Profit',
                NumberFormatter.format(n('total_profit')),
                Iconsax.wallet_money,
                AppColors.success,
                sub: '${o['commission_percent'] ?? 0}% margin',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard(
                'Deposited',
                NumberFormatter.format(n('total_deposited')),
                Iconsax.receive_square,
                AppColors.diamond,
              ),
              const SizedBox(width: 12),
              _statCard(
                'Coin Sellers',
                '${n('seller_count')}',
                Iconsax.people,
                AppColors.accent,
              ),
            ],
          ),
          if (n('pending_withdrawal_count') > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Iconsax.clock,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${n('pending_withdrawal_count')} withdrawal(s) pending · '
                      '${NumberFormatter.format(n('pending_withdrawal_coins'))} coins held',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          _withdrawalsList(),
        ],
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? sub,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  sub,
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _withdrawalsList() {
    final async = ref.watch(merchantWithdrawalsProvider);
    return async.maybeWhen(
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Withdrawals',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...rows.take(10).map((w) {
              final status = w['status']?.toString() ?? 'pending';
              final color = switch (status) {
                'paid' => AppColors.success,
                'approved' => AppColors.diamond,
                'rejected' => AppColors.error,
                _ => AppColors.primary,
              };
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${NumberFormatter.format((w['amount_coins'] as num?)?.toInt() ?? 0)} coins',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fmtDate(w['requested_at']),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  // ── tab 1: recharge a coin seller ────────────────────────────────

  Widget _rechargeTab(Map<String, dynamic> o) {
    final balance = (o['wallet_balance'] as num?)?.toInt() ?? 0;
    final blocked = o['is_blocked'] == true;
    final resultsAsync = _toUser
        ? ref.watch(merchantUserSearchProvider(_searchQuery))
        : ref.watch(merchantSellerSearchProvider(_searchQuery));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance: ${NumberFormatter.format(balance)} coins',
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _targetTab('Coin seller', !_toUser, () {
                  setState(() {
                    _toUser = false;
                    _selectedSeller = null;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                }),
                _targetTab('User ID', _toUser, () {
                  setState(() {
                    _toUser = true;
                    _selectedSeller = null;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _toUser
                ? 'Coins go straight to the player\'s balance to spend.'
                : 'Coins go to the seller\'s stock to resell.',
            style: const TextStyle(color: Colors.white38, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            enabled: !blocked,
            style: const TextStyle(color: Colors.white),
            onChanged: (v) => setState(() {
              _searchQuery = v;
              _selectedSeller = null;
            }),
            decoration: InputDecoration(
              hintText: _toUser
                  ? 'Search user by ID or name'
                  : 'Search coin seller by ID or name',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(
                Iconsax.search_normal,
                color: Colors.white38,
                size: 18,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_selectedSeller == null)
            resultsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
              error: (e, _) => Text(
                'Search failed: $e',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
              data: (rows) {
                if (_searchQuery.trim().isEmpty) {
                  return _hint(
                    _toUser
                        ? 'Enter a player\'s numeric ID to top up their balance.'
                        : 'Enter a coin seller\'s numeric ID to send them coin stock.',
                  );
                }
                if (rows.isEmpty) {
                  return _hint(
                    _toUser
                        ? 'No account found with that ID or name.'
                        : 'No coin seller found. Only accounts marked as coin sellers can be recharged.',
                  );
                }
                return Column(
                  children: rows
                      .map(
                        (s) => _sellerRow(
                          s,
                          onTap: () => setState(() => _selectedSeller = s),
                        ),
                      )
                      .toList(),
                );
              },
            )
          else ...[
            _sellerRow(_selectedSeller!, selected: true),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Amount in coins',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _busy || blocked
                    ? null
                    : () {
                        final amt =
                            int.tryParse(_amountController.text.trim()) ?? 0;
                        if (amt <= 0) {
                          _resultDialog(
                            ok: false,
                            title: 'Invalid Amount',
                            message: 'Enter an amount greater than zero.',
                          );
                          return;
                        }
                        if (amt > balance) {
                          _resultDialog(
                            ok: false,
                            title: 'Insufficient Balance',
                            message:
                                'You hold ${NumberFormatter.format(balance)} coins.',
                          );
                          return;
                        }
                        _confirmRecharge(amt, _selectedSeller!);
                      },
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Send Coins',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _selectedSeller = null;
                  _amountController.clear();
                }),
                child: const Text(
                  'Choose a different seller',
                  style: TextStyle(color: Colors.white54, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _targetTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.black : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12.5,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _sellerRow(
    Map<String, dynamic> s, {
    VoidCallback? onTap,
    bool selected = false,
  }) {
    final avatar = s['avatar_url']?.toString();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar != null && avatar.isNotEmpty
                  ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
                  : const Icon(Iconsax.user, color: Colors.white38, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          s['username']?.toString() ?? 'Seller',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (s['is_mine'] == true || s['is_linked'] == true)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'MINE',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID ${s['short_id'] ?? '—'} · stock '
                    '${NumberFormatter.format((s['reseller_coins'] as num?)?.toInt() ?? 0)}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                color: Colors.white24,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // ── tab 2: my coin sellers ───────────────────────────────────────

  Widget _sellersTab() {
    final async = ref.watch(merchantResellersProvider);
    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: asyncErrorWidget(e, style: const TextStyle(color: Colors.white)),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return _hint(
            'No coin sellers yet. Recharge a seller from the Recharge tab and they will appear here.',
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final s = rows[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  _sellerRowInner(s),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      _miniStat(
                        'Supplied',
                        NumberFormatter.format(
                          (s['total_supplied'] as num?)?.toInt() ?? 0,
                        ),
                      ),
                      _miniStat('Times', '${s['supply_count'] ?? 0}'),
                      _miniStat('Last', _fmtDate(s['last_supplied_at'])),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sellerRowInner(Map<String, dynamic> s) {
    final avatar = s['avatar_url']?.toString();
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(11),
          ),
          clipBehavior: Clip.antiAlias,
          child: avatar != null && avatar.isNotEmpty
              ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
              : const Icon(Iconsax.user, color: Colors.white38, size: 17),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s['username']?.toString() ?? 'Seller',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ID ${s['short_id'] ?? '—'} · stock '
                '${NumberFormatter.format((s['reseller_coins'] as num?)?.toInt() ?? 0)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _tab = 1;
            _selectedSeller = s;
            _searchQuery = '';
            _searchController.clear();
          }),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: Size.zero,
          ),
          child: const Text(
            'Recharge',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  // ── tab 3: history ───────────────────────────────────────────────

  Widget _historyTab() {
    final async = ref.watch(merchantLedgerProvider(_ledgerFilter));
    const filters = <String, String?>{
      'All': null,
      'Deposits': 'deposits',
      'Sales': 'sales',
      'Withdrawals': 'withdrawals',
    };

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: filters.entries.map((e) {
              final active = _ledgerFilter == e.value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _ledgerFilter = e.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? AppColors.primary.withOpacity(0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      e.key,
                      style: TextStyle(
                        color: active ? AppColors.primary : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(
              child: asyncErrorWidget(
                e,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            data: (rows) {
              if (rows.isEmpty) return _hint('No records yet.');
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                itemCount: rows.length,
                itemBuilder: (_, i) => _ledgerRow(rows[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _ledgerRow(Map<String, dynamic> r) {
    final type = r['entry_type']?.toString() ?? '';
    final credit = ((r['direction'] as num?)?.toInt() ?? -1) > 0;
    final amount = (r['amount'] as num?)?.toInt() ?? 0;
    final profit = (r['profit_coins'] as num?)?.toInt() ?? 0;

    final (label, icon) = switch (type) {
      'admin_deposit' => ('Admin Recharge', Iconsax.receive_square),
      'admin_deduct' => ('Admin Deduction', Iconsax.send_square),
      'reseller_recharge' => ('Sold to Seller', Iconsax.shop),
      'withdrawal_hold' => ('Withdrawal Requested', Iconsax.clock),
      'withdrawal_paid' => ('Withdrawal Paid', Iconsax.money_send),
      'withdrawal_refund' => ('Withdrawal Refunded', Iconsax.refresh),
      _ => ('Adjustment', Iconsax.edit),
    };
    final color = credit ? AppColors.success : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (r['counterparty_name'] != null)
                      '${r['counterparty_name']} (ID ${r['counterparty_sid'] ?? '—'})',
                    _fmtDate(r['created_at']),
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (r['note'] != null &&
                    r['note'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    r['note'].toString(),
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${credit ? '+' : '−'}${NumberFormatter.format(amount)}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
              if (profit > 0)
                Text(
                  'profit ${NumberFormatter.format(profit)}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 9.5,
                  ),
                ),
              Text(
                'bal ${NumberFormatter.format((r['balance_after'] as num?)?.toInt() ?? 0)}',
                style: const TextStyle(color: Colors.white24, fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '—';
    return DateFormat('d MMM, HH:mm').format(d.toLocal());
  }
}
