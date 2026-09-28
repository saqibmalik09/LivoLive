import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/features/wallet/providers/coin_merchants_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class CoinMerchantListScreen extends ConsumerWidget {
  const CoinMerchantListScreen({super.key});

  static const _blue = Color(0xFF2F80ED);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coinMerchantsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
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
          context.l10n.wallet_coinMerchants,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              context.l10n.wallet_buyFromResellers,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: _blue)),
              error: (e, _) => asyncErrorWidget(e),
              data: (merchants) {
                if (merchants.isEmpty) {
                  return const Center(
                    child: Text(
                      'No coin merchants available',
                      style: TextStyle(color: Colors.black45),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: merchants.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    return _MerchantCard(merchant: merchants[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantCard extends StatefulWidget {
  const _MerchantCard({required this.merchant});

  final CoinMerchant merchant;

  @override
  State<_MerchantCard> createState() => _MerchantCardState();
}

class _MerchantCardState extends State<_MerchantCard> {
  bool _contacting = false;

  Future<void> _contact() async {
    if (_contacting) return;
    setState(() => _contacting = true);
    try {
      final convId = await ChatService.getOrCreateConversation(
        widget.merchant.id,
      );
      if (!mounted) return;
      context.push(
        AppRouter.chat,
        extra: {
          'conversationId': convId,
          'targetUserId': widget.merchant.id,
          'targetUsername': widget.merchant.username,
          'targetAvatar': widget.merchant.avatarUrl,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open chat: $e')));
      }
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  String _flagEmoji(String? code) {
    if (code == null || code.isEmpty) return '🏳️';
    try {
      return Country.parse(code).flagEmoji;
    } catch (_) {
      return '🏳️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.merchant;
    final reg = m.registrationDate != null
        ? DateFormat('yyyy-MM-dd').format(m.registrationDate!)
        : '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: m.avatarUrl != null && m.avatarUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: m.avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.person),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.person),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${m.shortId ?? '—'}',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: _contacting ? null : _contact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CoinMerchantListScreen._blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: StadiumBorder(side: BorderSide.none),
                  ),
                  child: _contacting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Contact',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _flagEmoji(m.countryCode),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Location',
                        style: TextStyle(color: Colors.black45, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        reg,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Registration Date',
                        style: TextStyle(color: Colors.black45, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        m.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: m.isOnline
                              ? const Color(0xFF2E7D32)
                              : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Status',
                        style: TextStyle(color: Colors.black45, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
