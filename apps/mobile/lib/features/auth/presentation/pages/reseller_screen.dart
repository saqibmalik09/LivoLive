import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/util/user_search_query.dart';
import 'package:sk_live/features/auth/presentation/widgets/reseller_policy_section.dart';
import 'package:sk_live/features/auth/presentation/widgets/reseller_bills_section.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

final resellerHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client.rpc(
        'get_reseller_history',
        params: {'p_user_id': user.id},
      );

      return List<Map<String, dynamic>>.from(response as List);
    });

class ResellerScreen extends ConsumerStatefulWidget {
  const ResellerScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<ResellerScreen> createState() => _ResellerScreenState();
}

class _ResellerScreenState extends ConsumerState<ResellerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _searchQuery = '';
  Map<String, dynamic>? _selectedUser;
  bool _isTransferring = false;
  final _formKey = GlobalKey<FormState>();
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleTransfer(
    int amount,
    Map<String, dynamic> recipient,
  ) async {
    final sender = Supabase.instance.client.auth.currentUser;
    if (sender == null) return;

    setState(() => _isTransferring = true);

    try {
      final response =
          await Supabase.instance.client.rpc(
                'transfer_coins_reseller',
                params: {
                  'p_sender_id': sender.id,
                  'p_receiver_id': recipient['id'],
                  'p_amount': amount,
                },
              )
              as Map<dynamic, dynamic>;

      final bool success = response['success'] ?? false;
      final String message = response['message'] ?? 'An error occurred';

      if (!mounted) return;

      if (success) {
        _showStatusDialog(
          isSuccess: true,
          title: context.l10n.reseller_transferSuccessful,
          message:
              'Successfully sent ${NumberFormatter.format(amount)} Coins to ${recipient['username']}.',
        );

        _amountController.clear();
        setState(() {
          _selectedUser = null;
          _searchQuery = '';
          _searchController.clear();
        });

        ref.invalidate(userProfileProvider);
        ref.invalidate(resellerHistoryProvider);
      } else {
        _showStatusDialog(
          isSuccess: false,
          title: 'Transfer Failed',
          message: message,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showStatusDialog(
        isSuccess: false,
        title: 'Transfer Error',
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }

  void _showStatusDialog({
    required bool isSuccess,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: isSuccess ? AppColors.success : AppColors.error,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: isSuccess ? AppColors.success : AppColors.error,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess
                    ? AppColors.success
                    : AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmTransfer(int amount, Map<String, dynamic> recipient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Coin Transfer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'Are you sure you want to transfer '),
              TextSpan(
                text: '${NumberFormatter.format(amount)} Coins',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: ' to '),
              TextSpan(
                text: '${recipient['username']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text:
                    ' (UID: ${recipient['short_id'] ?? recipient['id'].toString().substring(0, 8)})?',
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleTransfer(amount, recipient);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final historyAsync = ref.watch(resellerHistoryProvider);
    final searchResultsAsync = ref.watch(userSearchProvider(_searchQuery));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'Reseller Center',
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
            onPressed: () {
              ref.invalidate(userProfileProvider);
              ref.invalidate(resellerHistoryProvider);
              ref.invalidate(coinSellerPolicyProvider);
              ref.invalidate(resellerBillsProvider);
            },
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
        child: userProfileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) =>
              asyncErrorWidget(e, style: const TextStyle(color: Colors.white)),
          data: (profile) {
            final int coinsBalance =
                (profile?['reseller_coins'] as num?)?.toInt() ?? 0;

            return SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: kToolbarHeight + 10),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.3),
                              AppColors.accent.withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Iconsax.coin_1_copy,
                                color: AppColors.gold,
                                size: 36,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reseller Coin Balance',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          NumberFormatter.format(coinsBalance),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Coins',
                                          style: TextStyle(
                                            color: AppColors.gold,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          for (final entry in [
                            (0, 'Sell'),
                            (1, 'Bills'),
                            (2, 'History'),
                          ])
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: entry.$1 < 2 ? 8 : 0,
                                ),
                                child: GestureDetector(
                                  onTap: () => setState(() => _tab = entry.$1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _tab == entry.$1
                                          ? AppColors.primary
                                          : const Color(0xFF1E1E30),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _tab == entry.$1
                                            ? AppColors.primary
                                            : Colors.white.withOpacity(0.06),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      entry.$2,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(
                                          _tab == entry.$1 ? 1 : 0.6,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      if (_tab == 1) ...[
                        const ResellerBillsSection(),
                        const SizedBox(height: 40),
                      ] else if (_tab == 2) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Transfer History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  ref.invalidate(resellerHistoryProvider),
                              icon: const Icon(
                                Icons.refresh,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              label: const Text(
                                'Refresh',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        historyAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          error: (err, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'Error loading history: $err',
                                style: const TextStyle(color: Colors.white38),
                              ),
                            ),
                          ),
                          data: (historyList) {
                            if (historyList.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 36),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Iconsax.box_copy,
                                        color: Colors.white24,
                                        size: 40,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'No transfers yet.',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: historyList.length,
                              itemBuilder: (context, index) {
                                final item = historyList[index];
                                final amount =
                                    (item['amount'] as num?)?.toInt() ?? 0;
                                final createdAtStr =
                                    item['created_at'] as String?;
                                final receiverUsername =
                                    item['receiver_username'] ?? 'User';
                                final receiverShortId =
                                    item['receiver_short_id'];
                                final receiverAvatar =
                                    item['receiver_avatar_url'];

                                String displayDate = '';
                                if (createdAtStr != null) {
                                  try {
                                    final dt = DateTime.parse(
                                      createdAtStr,
                                    ).toLocal();
                                    displayDate = DateFormat(
                                      'yyyy-MM-dd HH:mm',
                                    ).format(dt);
                                  } catch (_) {
                                    displayDate = createdAtStr;
                                  }
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E30),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.02),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: receiverAvatar != null
                                            ? CachedNetworkImageProvider(
                                                receiverAvatar,
                                              )
                                            : null,
                                        backgroundColor: Colors.grey.shade800,
                                        child: receiverAvatar == null
                                            ? const Icon(
                                                Icons.person,
                                                color: Colors.white30,
                                                size: 18,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              receiverUsername,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'UID: ${receiverShortId ?? "N/A"} • $displayDate',
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '-${NumberFormatter.format(amount)}',
                                            style: const TextStyle(
                                              color: AppColors.gold,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'Coins',
                                            style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                      ] else ...[
                        const ResellerPolicySection(),

                        const Text(
                          '1. Select Client Recipient',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_selectedUser == null) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText:
                                    'Search by client username or numeric UID...',
                                hintStyle: const TextStyle(
                                  color: Colors.white30,
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(
                                  Iconsax.search_normal_copy,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          color: Colors.white54,
                                        ),
                                        onPressed: () => setState(() {
                                          _searchQuery = '';
                                          _searchController.clear();
                                        }),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (isUserSearchQueryReady(_searchQuery))
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E30),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: searchResultsAsync.when(
                                loading: () => const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                error: (err, _) => asyncErrorWidget(
                                  err,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                                data: (users) {
                                  if (users.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'No users found',
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    );
                                  }
                                  return ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    itemCount: users.length,
                                    separatorBuilder: (context, index) =>
                                        Divider(
                                          color: Colors.white.withOpacity(0.05),
                                          height: 1,
                                        ),
                                    itemBuilder: (context, index) {
                                      final u = users[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage:
                                              u['avatar_url'] != null
                                              ? CachedNetworkImageProvider(
                                                  u['avatar_url'],
                                                )
                                              : null,
                                          backgroundColor: Colors.grey.shade800,
                                          child: u['avatar_url'] == null
                                              ? const Icon(
                                                  Icons.person,
                                                  color: Colors.white54,
                                                )
                                              : null,
                                        ),
                                        title: Text(
                                          u['username'] ?? 'User',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'UID: ${u['short_id'] ?? "N/A"}',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          color: Colors.white24,
                                          size: 14,
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _selectedUser = u;
                                            _searchQuery = '';
                                            _searchController.clear();
                                          });
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage:
                                      _selectedUser!['avatar_url'] != null
                                      ? CachedNetworkImageProvider(
                                          _selectedUser!['avatar_url'],
                                        )
                                      : null,
                                  backgroundColor: Colors.grey.shade800,
                                  child: _selectedUser!['avatar_url'] == null
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white54,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedUser!['username'] ?? 'User',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'UID: ${_selectedUser!['short_id'] ?? "N/A"}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () =>
                                      setState(() => _selectedUser = null),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        const Text(
                          '2. Enter Coins Amount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E30),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                ),
                                child: TextFormField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Enter amount...',
                                    hintStyle: TextStyle(
                                      color: Colors.white30,
                                      fontSize: 16,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    prefixIcon: Icon(
                                      Iconsax.coin_1_copy,
                                      color: AppColors.gold,
                                      size: 22,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a coins amount';
                                    }
                                    final int? amt = int.tryParse(value);
                                    if (amt == null || amt <= 0) {
                                      return 'Please enter a valid amount greater than 0';
                                    }
                                    if (amt > coinsBalance) {
                                      return 'Insufficient reseller coins (max $coinsBalance)';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [1000, 5000, 10000, 50000].map((
                                  quickAmt,
                                ) {
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          _amountController.text = quickAmt
                                              .toString();
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E1E30),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.05,
                                              ),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '+${NumberFormatter.format(quickAmt)}',
                                            style: const TextStyle(
                                              color: AppColors.gold,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: _selectedUser != null
                                        ? AppColors.primaryGradient
                                        : null,
                                    color: _selectedUser == null
                                        ? Colors.white10
                                        : null,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ElevatedButton(
                                    onPressed:
                                        (_selectedUser == null ||
                                            _isTransferring)
                                        ? null
                                        : () {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              final int amt = int.parse(
                                                _amountController.text,
                                              );
                                              _confirmTransfer(
                                                amt,
                                                _selectedUser!,
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isTransferring
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Transfer Coins',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
