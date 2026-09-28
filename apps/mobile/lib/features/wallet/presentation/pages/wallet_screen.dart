import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/providers/wallet_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/util/user_search_query.dart';
import 'package:sk_live/features/chat/presentation/pages/feedback_screen.dart';
import 'package:sk_live/features/auth/presentation/pages/reseller_screen.dart';
import 'package:sk_live/features/wallet/presentation/pages/coin_merchant_list_screen.dart';
import 'package:sk_live/features/wallet/presentation/pages/exchange_balance_screen.dart';
import 'package:sk_live/features/wallet/presentation/pages/wallet_record_screen.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class _DummyProduct implements ProductDetails {
  @override
  final String id;
  @override
  final String title = 'Loading...';
  @override
  final String description = '';
  @override
  final String price;
  @override
  final double rawPrice;
  @override
  final String currencyCode = 'USD';
  @override
  final String currencySymbol = '\$';

  _DummyProduct(this.id, this.rawPrice)
    : price = '\$${rawPrice.toStringAsFixed(2)}';
}

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  static const _pink = Color(0xFFFF4D8D);
  static const _pinkSoft = Color(0xFFFFE4EF);

  late TabController _tabController;
  final TextEditingController _diamondExchangeController =
      TextEditingController();
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _otherIdController = TextEditingController();

  int _selectedPackageIndex = 0;
  int _diamondSegment = 0;
  int _cashSegment = 0;
  double? _selectedCashUsd = 10;
  Map<String, dynamic>? _cashTargetUser;
  bool _cashBusy = false;

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isIAPAvailable = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeIAP();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(canAccessDiamondsProvider);
      ref.invalidate(userProfileProvider);
    });
  }

  Future<void> _initializeIAP() async {
    final bool available = await _iap.isAvailable();
    if (mounted) setState(() => _isIAPAvailable = available);

    if (available) {
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription.cancel(),
        onError: (error) => debugPrint('IAP Error: $error'),
      );
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    try {
      final packages = await ref.read(rechargePackagesProvider.future);
      final productIds = packages
          .map((p) => p.playStoreId)
          .whereType<String>()
          .toSet();

      if (productIds.isNotEmpty) {
        final ProductDetailsResponse response = await _iap.queryProductDetails(
          productIds,
        );
        if (mounted) {
          setState(() {
            _products = List<ProductDetails>.from(response.productDetails);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading Play Store products: $e');
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Purchase Error: ${purchase.error?.message ?? "Unknown error"}',
            ),
          ),
        );
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _verifyAndDeliverPurchase(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndDeliverPurchase(PurchaseDetails purchase) async {
    try {
      final purchaseId = purchase.purchaseID;
      if (purchaseId == null || purchaseId.isEmpty) {
        debugPrint('IAP missing purchaseID');
        return;
      }

      final packages = await ref.read(rechargePackagesProvider.future);
      final pkg = packages.firstWhere(
        (p) => p.playStoreId == purchase.productID,
      );

      final result = await ref
          .read(walletActionsProvider)
          .deliverIapPurchase(
            productId: purchase.productID,
            purchaseId: purchaseId,
            purchaseToken: purchase.verificationData.serverVerificationData,
          );

      final ok = result['success'] == true;
      if (ok && mounted) {
        final coins = (result['coins'] as num?)?.toInt() ?? pkg.coinsAmount;
        final dup = result['duplicate'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dup
                  ? 'Purchase already credited ($coins coins)'
                  : context.l10n.wallet_rechargeSuccess('$coins'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(userProfileProvider);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recharge failed: ${result['message'] ?? 'unknown'}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error delivering purchase: $e');
    }
  }

  void _buySelectedPackage(List<RechargePackage> packages) {
    if (packages.isEmpty) return;
    final pkg = packages[_selectedPackageIndex.clamp(0, packages.length - 1)];
    try {
      final product = _products.firstWhere(
        (p) => p.id == pkg.playStoreId,
        orElse: () => throw 'Product not found in Play Store',
      );
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );
      _iap.buyConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _diamondExchangeController.dispose();
    _cashAmountController.dispose();
    _otherIdController.dispose();
    if (_isIAPAvailable) _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final diamondsAccess = ref.watch(canAccessDiamondsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          context.l10n.wallet_title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Iconsax.document_text,
              color: Colors.black54,
              size: 22,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletRecordScreen()),
              );
            },
            tooltip: context.l10n.wallet_recordTooltip,
          ),
        ],
      ),
      body: userProfileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _pink)),
        error: (e, _) => asyncErrorWidget(e),
        data: (profile) {
          final coins = (profile?['coins'] as num?)?.toInt() ?? 0;
          final diamonds = (profile?['diamonds'] as num?)?.toInt() ?? 0;
          final cash = (profile?['cash_balance'] as num?)?.toDouble() ?? 0.0;
          final isReseller = profile?['is_reseller'] == true;
          final canDiamonds = diamondsAccess.valueOrNull ?? false;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _pillTabs(),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGoldCoinsTab(coins, isReseller),
                    _buildDiamondsTab(diamonds, canDiamonds),
                    _buildBalanceTab(cash),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pillTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(28),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _pink,
          borderRadius: BorderRadius.circular(24),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: _pink,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: [
          Tab(text: context.l10n.wallet_tabGoldCoins),
          Tab(text: context.l10n.wallet_tabDiamonds),
          Tab(text: context.l10n.wallet_tabBalance),
        ],
      ),
    );
  }

  Widget _buildGoldCoinsTab(int coins, bool isReseller) {
    final packagesAsync = ref.watch(rechargePackagesProvider);

    return packagesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _pink)),
      error: (e, _) => asyncErrorWidget(e),
      data: (packages) {
        if (packages.isNotEmpty && _selectedPackageIndex >= packages.length) {
          _selectedPackageIndex = 0;
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _goldBalanceCard(coins),
                  const SizedBox(height: 12),
                  _coinMerchantsBanner(),
                  const SizedBox(height: 12),
                  if (isReseller) ...[
                    _resellerBanner(),
                    const SizedBox(height: 16),
                  ],
                  if (!_isIAPAvailable)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        context.l10n.wallet_paymentUnavailable,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black45),
                      ),
                    )
                  else
                    ...List.generate(packages.length, (i) {
                      final pkg = packages[i];
                      final selected = i == _selectedPackageIndex;
                      final playStoreProduct = _products.firstWhere(
                        (p) => p.id == pkg.playStoreId,
                        orElse: () =>
                            _DummyProduct(pkg.playStoreId ?? '', pkg.priceUsd),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _selectableRow(
                          selected: selected,
                          onTap: () =>
                              setState(() => _selectedPackageIndex = i),
                          leading: const Icon(
                            Iconsax.coin_1_copy,
                            color: Color(0xFFE6A800),
                            size: 28,
                          ),
                          title: NumberFormatter.format(pkg.coinsAmount),
                          trailing: playStoreProduct.price.startsWith('USD')
                              ? playStoreProduct.price
                              : 'USD ${pkg.priceUsd.toStringAsFixed(2)}',
                        ),
                      );
                    }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: packages.isEmpty
                      ? null
                      : () => _buySelectedPackage(packages),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _pink.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'pay',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.wallet_rechargeIssuesPrefix,
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                    ),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.wallet_contactUs,
                          style: const TextStyle(
                            color: Color(0xFF2F80ED),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.phone,
                          size: 14,
                          color: Color(0xFF2F80ED),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _goldBalanceCard(int coins) {
    return _walletHeroCard(
      height: 120,
      gradient: const LinearGradient(
        colors: [Color(0xFFF6C453), Color(0xFFE89A1C), Color(0xFFF0B429)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      shadowColor: const Color(0xFFE89A1C).withValues(alpha: 0.35),
      imageAsset: 'assets/wallet/wallet_coins.webp',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.wallet_coinBalance,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            NumberFormatter.format(coins),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletHeroCard({
    required double height,
    required Gradient gradient,
    required String imageAsset,
    required Widget child,
    Color? shadowColor,
    Widget? trailing,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: gradient,
        boxShadow: shadowColor == null
            ? null
            : [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -6,
            bottom: -6,
            child: Opacity(
              opacity: 0.95,
              child: Image.asset(
                imageAsset,
                width: 128,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 110, 16),
            child: Row(
              children: [
                Expanded(child: child),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resellerBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResellerScreen()),
      ),
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1030), Color(0xFF3D1A4A), Color(0xFF6B2040)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Iconsax.shop_add, color: Color(0xFFFFD56A), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.wallet_goldCoinReseller,
                    style: const TextStyle(
                      color: Color(0xFFFFD56A),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.wallet_openResellerCenter,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _selectableRow({
    required bool selected,
    required VoidCallback onTap,
    required Widget leading,
    required String title,
    required String trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _pink : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Text(
                  trailing,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            if (selected)
              const Positioned(
                right: 0,
                top: 0,
                child: Icon(Icons.check_circle, color: _pink, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiamondsTab(int diamonds, bool canAccess) {
    if (!canAccess) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Diamond earnings unlock when you join an agency as a host, or become agency owner / BD staff.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
        ),
      );
    }

    final configsAsync = ref.watch(exchangeConfigsProvider);

    return configsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _pink)),
      error: (e, _) => asyncErrorWidget(e),
      data: (configs) {
        final config = configs.firstWhere(
          (c) => c.fromCurrency == 'diamonds' && c.toCurrency == 'coins',
          orElse: () => configs.isNotEmpty
              ? configs.first
              : ExchangeConfig(
                  id: '',
                  fromCurrency: 'diamonds',
                  toCurrency: 'coins',
                  rate: 0.9,
                  minAmount: 1000,
                ),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            _diamondBalanceCard(diamonds),
            const SizedBox(height: 14),
            _segmented(
              left: context.l10n.wallet_exchangeGoldCoins,
              right: context.l10n.wallet_exchangeToSalary,
              selected: _diamondSegment,
              onChanged: (i) => setState(() {
                _diamondSegment = i;
                _diamondExchangeController.clear();
              }),
              activeColor: _diamondSegment == 0
                  ? const Color(0xFF4C8DFF)
                  : const Color(0xFFFF8A3D),
            ),
            const SizedBox(height: 18),
            if (_diamondSegment == 0) ...[
              Text(
                context.l10n.wallet_exchangeGoldCoins,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${config.minAmount} diamonds can be exchanged for ${(config.minAmount * config.rate).floor()} gold coins, and can be exchanged in multiples of ${config.minAmount}.',
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              _inputWithMax(
                controller: _diamondExchangeController,
                hint: context.l10n.wallet_enterExchangeAmount,
                maxLabel: context.l10n.wallet_maximum,
                onMax: () => setState(
                  () => _diamondExchangeController.text = diamonds.toString(),
                ),
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (_) {
                  final amount =
                      int.tryParse(_diamondExchangeController.text) ?? 0;
                  final receive = (amount * config.rate).floor();
                  return Row(
                    children: [
                      Text(
                        context.l10n.wallet_redeemablePrefix,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 13,
                        ),
                      ),
                      const Icon(
                        Iconsax.coin_1_copy,
                        size: 16,
                        color: Color(0xFFE6A800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        NumberFormatter.format(receive),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _performDiamondExchange(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7EB6FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    context.l10n.wallet_exchangeGoldCoins,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ] else
              _buildSalaryExchangeSection(diamonds),
          ],
        );
      },
    );
  }

  Widget _buildSalaryExchangeSection(int diamonds) {
    const accent = Color(0xFFFF8A3D);
    final salaryCfgAsync = ref.watch(diamondSalaryConfigProvider);

    return salaryCfgAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: accent)),
      ),
      error: (e, _) => asyncErrorWidget(e),
      data: (cfg) {
        final salaryCfg =
            cfg ??
            const DiamondSalaryConfig(
              id: '',
              diamondsUnit: 150000,
              usdPerUnit: 0.75,
            );
        final unit = salaryCfg.diamondsUnit;
        final usdUnit = salaryCfg.usdPerUnit;
        final amount = int.tryParse(_diamondExchangeController.text) ?? 0;
        final redeemUsd = salaryCfg.usdForDiamonds(amount);
        final canExchange =
            amount >= unit && amount % unit == 0 && amount <= diamonds;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.wallet_exchangeToSalary,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: '$unit',
                    style: const TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' diamonds can be exchanged for '),
                  TextSpan(
                    text: '\$${usdUnit.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(
                    text: ', and can be exchanged in multiples of ',
                  ),
                  TextSpan(
                    text: '$unit',
                    style: const TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                  height: 1.45,
                ),
                children: [
                  TextSpan(text: context.l10n.wallet_afterSalaryExchangePrefix),
                  TextSpan(
                    text: context.l10n.wallet_exchangeForGoldCoins,
                    style: const TextStyle(
                      color: Color(0xFFFFC107),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: context.l10n.wallet_inWalletAnytime),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _inputWithMax(
              controller: _diamondExchangeController,
              hint: '0',
              maxLabel: context.l10n.wallet_maximum,
              maxColor: accent,
              onMax: () => setState(() {
                _diamondExchangeController.text = salaryCfg
                    .maxExchangeable(diamonds)
                    .toString();
              }),
            ),
            const SizedBox(height: 10),
            Text(
              '${context.l10n.wallet_redeemablePrefix}\$${redeemUsd.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: canExchange
                    ? () => _performSalaryExchange(diamonds)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: accent.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  context.l10n.wallet_exchangeToSalary,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _diamondBalanceCard(int diamonds) {
    return _walletHeroCard(
      height: 120,
      gradient: const LinearGradient(
        colors: [Color(0xFF5B7CFF), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      imageAsset: 'assets/wallet/wallet_diamonds.webp',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.wallet_earnByParticipation,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.wallet_diamond,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            NumberFormatter.format(diamonds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDiamondExchange() async {
    final amount = int.tryParse(_diamondExchangeController.text) ?? 0;
    if (amount <= 0) return;
    try {
      final success = await ref
          .read(walletActionsProvider)
          .performExchange(
            fromCurrency: 'diamonds',
            toCurrency: 'coins',
            amount: amount,
          );
      if (success && mounted) {
        _diamondExchangeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.wallet_exchangeSuccessful),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _performSalaryExchange(int diamondsBalance) async {
    final amount = int.tryParse(_diamondExchangeController.text) ?? 0;
    if (amount <= 0) return;
    try {
      final res = await ref
          .read(walletActionsProvider)
          .exchangeDiamondsToSalary(amount);
      if (!mounted) return;
      final ok = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ??
                (ok
                    ? context.l10n.wallet_exchangeSuccessful
                    : context.l10n.wallet_exchangeFailed),
          ),
          backgroundColor: ok ? Colors.green : Colors.redAccent,
        ),
      );
      if (ok) {
        _diamondExchangeController.clear();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildBalanceTab(double cash) {
    final cfgAsync = ref.watch(cashExchangeConfigProvider);
    final chips = <double>[5, 10, 50, 100];

    return cfgAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _pink)),
      error: (e, _) => asyncErrorWidget(e),
      data: (cfg) {
        final config =
            cfg ??
            const CashExchangeConfig(
              id: '',
              coinsPerDollar: 68000,
              bonusPercent: 32,
            );
        final usd = _resolveCashUsd(cash);
        final base = config.baseCoinsForUsd(usd);
        final bonus = config.bonusCoinsForUsd(usd);

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _cashBalanceCard(cash),
                  const SizedBox(height: 14),
                  _segmented(
                    left: context.l10n.wallet_exchangeToOneself,
                    right: context.l10n.wallet_exchangeToOther,
                    selected: _cashSegment,
                    onChanged: (i) => setState(() {
                      _cashSegment = i;
                      _cashTargetUser = null;
                    }),
                    activeColor: _pink,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.wallet_goldCoinsExchange,
                    style: const TextStyle(color: Colors.black45, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '1\$=${NumberFormatter.format(config.coinsPerDollar)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '+${NumberFormatter.format(config.bonusCoinsForUsd(1))}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: _pink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${config.bonusPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Color(0xFFE67E22),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use your wallet balance to purchase gold coins and get an extra bonus. Admin-funded cash wallet · 24h exchange.',
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_cashSegment == 1) ...[
                    _otherUserSearch(),
                    const SizedBox(height: 14),
                  ],
                  ...chips.map((c) {
                    final selected =
                        _selectedCashUsd == c &&
                        _cashAmountController.text.isEmpty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedCashUsd = c;
                          _cashAmountController.clear();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? _pink : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Text(
                                '\$${c.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              if (selected)
                                const Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: _pink,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  TextField(
                    controller: _cashAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() => _selectedCashUsd = null),
                    decoration: InputDecoration(
                      hintText: context.l10n.wallet_enterCoinsRedeemed,
                      filled: true,
                      fillColor: const Color(0xFFF7F7F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Iconsax.coin_1_copy,
                    color: Color(0xFFE6A800),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${NumberFormatter.format(base)}+${NumberFormatter.format(bonus)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const Text(
                          'redeem and obtain',
                          style: TextStyle(color: Colors.black45, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _cashBusy
                          ? null
                          : () => _submitCashExchange(cash, usd),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      child: _cashBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              context.l10n.wallet_exchange,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  double _resolveCashUsd(double cash) {
    final typed = double.tryParse(_cashAmountController.text.trim());
    if (typed != null && typed > 0) return typed;
    return _selectedCashUsd ?? 0;
  }

  Widget _cashBalanceCard(double cash) {
    return _walletHeroCard(
      height: 120,
      gradient: const LinearGradient(
        colors: [Color(0xFF5B7CFF), Color(0xFFA855F7), Color(0xFFEC4899)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      imageAsset: 'assets/wallet/wallet_cash.webp',
      trailing: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExchangeBalanceScreen()),
          );
        },
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.22),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          context.l10n.wallet_withdraw,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.wallet_cashWallet,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '\$${cash.toStringAsFixed(cash.truncateToDouble() == cash ? 0 : 2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coinMerchantsBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CoinMerchantListScreen()),
      ),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF3B82F6), Color(0xFF60A5FA)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -4,
              top: -8,
              bottom: -8,
              child: Image.asset(
                'assets/wallet/wallet_merchants.webp',
                width: 100,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 96, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.wallet_coinMerchants,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.wallet_buyFromResellers,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _otherUserSearch() {
    final resultsAsync = ref.watch(userSearchProvider(_otherIdController.text));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _otherIdController,
                onChanged: (_) => setState(() => _cashTargetUser = null),
                decoration: InputDecoration(
                  hintText: context.l10n.wallet_enterIdHint,
                  filled: true,
                  fillColor: const Color(0xFFF7F7F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
        if (_cashTargetUser != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _pinkSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_cashTargetUser!['username']} · ID ${_cashTargetUser!['short_id'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _cashTargetUser = null),
                ),
              ],
            ),
          ),
        ] else if (isUserSearchQueryReady(_otherIdController.text))
          resultsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(color: _pink),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (users) {
              if (users.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.l10n.wallet_noUserFound,
                    style: const TextStyle(color: Colors.black45),
                  ),
                );
              }
              return Column(
                children: users.take(5).map((u) {
                  return ListTile(
                    dense: true,
                    title: Text('${u['username']}'),
                    subtitle: Text('ID ${u['short_id'] ?? ''}'),
                    onTap: () => setState(() {
                      _cashTargetUser = Map<String, dynamic>.from(u);
                      _otherIdController.text =
                          u['short_id']?.toString() ?? u['username'] ?? '';
                    }),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Future<void> _submitCashExchange(double cash, double usd) async {
    if (usd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.wallet_enterValidAmount)),
      );
      return;
    }
    if (usd > cash) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.wallet_insufficientCash)),
      );
      return;
    }
    if (_cashSegment == 1 && _cashTargetUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.wallet_selectRecipient)),
      );
      return;
    }

    setState(() => _cashBusy = true);
    try {
      final Map<String, dynamic> res;
      if (_cashSegment == 0) {
        res = await ref.read(walletActionsProvider).exchangeCashToSelf(usd);
      } else {
        res = await ref
            .read(walletActionsProvider)
            .exchangeCashToOther(
              targetUserId: _cashTargetUser!['id'] as String,
              amountUsd: usd,
            );
      }
      if (!mounted) return;
      final ok = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${res['message'] ?? (ok ? 'Done' : 'Failed')}'),
          backgroundColor: ok ? Colors.green : Colors.redAccent,
        ),
      );
      if (ok) {
        _cashAmountController.clear();
        setState(() {
          _selectedCashUsd = 10;
          _cashTargetUser = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _cashBusy = false);
    }
  }

  Widget _segmented({
    required String left,
    required String right,
    required int selected,
    required ValueChanged<int> onChanged,
    required Color activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segChip(
              label: left,
              selected: selected == 0,
              color: activeColor,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _segChip(
              label: right,
              selected: selected == 1,
              color: activeColor,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _inputWithMax({
    required TextEditingController controller,
    required String hint,
    required String maxLabel,
    required VoidCallback onMax,
    Color maxColor = const Color(0xFF4C8DFF),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                hintStyle: const TextStyle(color: Colors.black38),
              ),
            ),
          ),
          TextButton(
            onPressed: onMax,
            style: TextButton.styleFrom(
              backgroundColor: maxColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(maxLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
