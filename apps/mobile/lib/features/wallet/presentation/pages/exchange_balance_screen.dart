import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/util/user_search_query.dart';
import 'package:sk_live/features/wallet/presentation/pages/bill_records_screen.dart';
import 'package:sk_live/features/wallet/presentation/pages/user_payment_methods_screen.dart';
import 'package:sk_live/features/wallet/providers/withdraw_provider.dart';

class ExchangeBalanceScreen extends ConsumerStatefulWidget {
  const ExchangeBalanceScreen({super.key});

  @override
  ConsumerState<ExchangeBalanceScreen> createState() =>
      _ExchangeBalanceScreenState();
}

class _ExchangeBalanceScreenState extends ConsumerState<ExchangeBalanceScreen> {
  static const _purple = Color(0xFF7E69FF);

  final _idController = TextEditingController();
  final _amountController = TextEditingController();

  int _segment = 0;
  bool get _isOfficial => _segment == 1;
  Map<String, dynamic>? _targetUser;
  UserPaymentMethod? _paymentMethod;
  bool _busy = false;
  bool _searching = false;

  @override
  void dispose() {
    _idController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _searchTarget() async {
    final q = _idController.text.trim();
    if (!isUserSearchQueryReady(q)) return;
    setState(() {
      _searching = true;
      _targetUser = null;
    });
    try {
      final users = await ref.read(userSearchProvider(q).future);
      if (!mounted) return;
      if (users.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.wallet_noUserFound)),
        );
        setState(() => _searching = false);
        return;
      }
      Map<String, dynamic>? exact;
      for (final u in users) {
        if (u['short_id']?.toString() == q) {
          exact = u;
          break;
        }
      }
      setState(() {
        _targetUser = exact ?? users.first;
        _searching = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  Future<void> _pickPaymentMethod() async {
    final methods = await ref.read(userPaymentMethodsProvider.future);
    if (!mounted) return;
    if (methods.isEmpty) {
      final created = await Navigator.push<UserPaymentMethod>(
        context,
        MaterialPageRoute(
          builder: (_) => const UserPaymentMethodsScreen(selectMode: true),
        ),
      );
      if (created != null) setState(() => _paymentMethod = created);
      return;
    }

    final selected = await showModalBottomSheet<UserPaymentMethod>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Material(
            color: Theme.of(ctx).colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    ctx.l10n.wallet_selectPaymentMethod,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                ...methods.map(
                  (m) => ListTile(
                    title: Text(
                      m.method,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${m.name} · ${m.address}'),
                    onTap: () => Navigator.pop(ctx, m),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add, color: _purple),
                  title: const Text('Add payment method'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final created = await Navigator.push<UserPaymentMethod>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const UserPaymentMethodsScreen(selectMode: true),
                      ),
                    );
                    if (created != null && mounted) {
                      setState(() => _paymentMethod = created);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) setState(() => _paymentMethod = selected);
  }

  Future<void> _confirm(double available) async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (!_isOfficial && _targetUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.wallet_searchSelectTargetId)),
      );
      return;
    }
    if (_paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.wallet_selectPaymentMethod)),
      );
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.wallet_enterValidAmount)),
      );
      return;
    }
    if (amount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.wallet_insufficientCash)),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await ref
          .read(withdrawActionsProvider)
          .requestWithdrawal(
            amount: amount,
            targetType: _isOfficial ? 'official' : 'reseller',
            targetUserId: _isOfficial ? null : _targetUser!['id'] as String,
            paymentMethodId: _paymentMethod!.id,
          );
      if (!mounted) return;
      final ok = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? (ok ? 'OK' : 'Failed')),
        ),
      );
      if (ok) {
        _amountController.clear();
        setState(() {
          _targetUser = null;
          _idController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final cash = (profile?['cash_balance'] as num?)?.toDouble() ?? 0.0;
    final cfg = ref.watch(withdrawalConfigProvider).valueOrNull;
    final minAmount = cfg?.minAmount ?? 1.0;
    final maxHint = cash < minAmount ? 0.0 : cash;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.l10n.wallet_cashWallet,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillRecordsScreen()),
              );
            },
            child: const Text(
              'Bill',
              style: TextStyle(
                color: _purple,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _availableCard(cash),
              const SizedBox(height: 14),
              _segmentToggle(),
              if (!_isOfficial) ...[
                const SizedBox(height: 14),
                _idSearchRow(),
                if (_targetUser != null) ...[
                  const SizedBox(height: 8),
                  _targetChip(),
                ],
              ],
              const SizedBox(height: 14),
              _amountCard(cash, minAmount, maxHint),
              const SizedBox(height: 14),
              _paymentMethodCard(),
              const SizedBox(height: 16),
              const Text(
                'A service fee will be deducted; please refer to the actual received amount',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45, fontSize: 12),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _confirm(cash),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Withdrawal dates are on the 1st, 2nd, 3rd, 4th, 5th, 16th, 17th, 18th, 19th and 20th of each month (UTC+3).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Material(
                  color: Color(0xFF333333),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                    child: Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _availableCard(double cash) {
    return Container(
      width: double.infinity,
      height: 128,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF7E69FF), Color(0xFF9B7BFF), Color(0xFFB794FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -12,
            bottom: -12,
            child: Image.asset(
              'assets/wallet/wallet_cash.webp',
              width: 140,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 120, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Amount available for withdrawal',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${cash.toStringAsFixed(cash.truncateToDouble() == cash ? 0 : 2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _segBtn('Coin Reseller Transfer', 0)),
          Expanded(child: _segBtn('Official', 1)),
        ],
      ),
    );
  }

  Widget _segBtn(String label, int index) {
    final selected = _segment == index;
    return GestureDetector(
      onTap: () => setState(() {
        _segment = index;
        _targetUser = null;
        _idController.clear();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _purple : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _idSearchRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _idController,
            onChanged: (_) => setState(() => _targetUser = null),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: context.l10n.wallet_enterIdHint,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _purple, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _purple, width: 1.6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: _purple,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _searching ? null : _searchTarget,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _targetChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_targetUser!['username']} · ID ${_targetUser!['short_id'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _targetUser = null),
          ),
        ],
      ),
    );
  }

  Widget _amountCard(double cash, double minAmount, double maxHint) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE8FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PK',
                  style: TextStyle(
                    color: _purple,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enter withdrawal amount (${minAmount.toStringAsFixed(0)}~${maxHint.toStringAsFixed(0)})',
                  style: const TextStyle(color: Colors.black45, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                '\$',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  _amountController.text = cash.toStringAsFixed(
                    cash.truncateToDouble() == cash ? 0 : 2,
                  );
                  setState(() {});
                },
                style: TextButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  context.l10n.wallet_maximum,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodCard() {
    return InkWell(
      onTap: _pickPaymentMethod,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: _purple),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _paymentMethod == null
                    ? context.l10n.wallet_selectPaymentMethod
                    : '${_paymentMethod!.method} · ${_paymentMethod!.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _paymentMethod == null
                      ? Colors.black54
                      : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
