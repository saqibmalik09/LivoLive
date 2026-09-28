import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/rupee_game_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/party_screen_background.dart';
import 'package:sk_live/features/rupee_game/presentation/pages/rupee_game_help_screen.dart';
import 'package:sk_live/features/rupee_game/presentation/widgets/rupee_game_prize_card.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class RupeeGameScreen extends ConsumerStatefulWidget {
  const RupeeGameScreen({super.key});

  @override
  ConsumerState<RupeeGameScreen> createState() => _RupeeGameScreenState();
}

class _RupeeGameScreenState extends ConsumerState<RupeeGameScreen> {
  String? _buyingPrizeId;

  Future<void> _refresh() async {
    ref.invalidate(activeRupeeGameCampaignsProvider);
    ref.invalidate(myRupeeGameEntriesProvider);
    ref.invalidate(rupeeGameHelpProvider);
    await ref.read(activeRupeeGameCampaignsProvider.future);
    await ref.read(myRupeeGameEntriesProvider.future);
  }

  Future<void> _onBuy(RupeeGamePrize prize, int entryPrice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.game_confirmParticipation),
        content: Text(
          'Pay $entryPrice coin${entryPrice == 1 ? '' : 's'} for a chance to win ${prize.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _buyingPrizeId = prize.id);
    try {
      final result = await enterRupeeGame(prize.id);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.game_participationConfirmed)),
        );
        ref.invalidate(myRupeeGameEntriesProvider);
        ref.invalidate(rupeeGamePrizesProvider(prize.campaignId));
        ref.invalidate(userProfileProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _buyingPrizeId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(activeRupeeGameCampaignsProvider);
    final entriesAsync = ref.watch(myRupeeGameEntriesProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: campaignsAsync.maybeWhen(
          data: (campaigns) => Text(
            campaigns.isNotEmpty
                ? campaigns.first.title
                : context.l10n.game_rupeeTitle,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          orElse: () => Text(
            context.l10n.game_rupeeTitle,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.info_circle, color: Colors.black54),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RupeeGameHelpScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PartyScreenBackground(),
          campaignsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => asyncErrorWidget(e),
            data: (campaigns) {
              final topPad = topInset + kToolbarHeight + 8;
              if (campaigns.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      topPad,
                      20,
                      kHomeTabScrollBottomPadding,
                    ),
                    children: const [
                      SizedBox(height: 80),
                      Icon(Iconsax.game, size: 64, color: Colors.black45),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No active campaign right now.\nCheck back soon!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final campaign = campaigns.first;
              final prizesAsync = ref.watch(
                rupeeGamePrizesProvider(campaign.id),
              );
              final enteredPrizeIds = entriesAsync.valueOrNull ?? {};

              return RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    topPad,
                    20,
                    kHomeTabScrollBottomPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.subtitle.isNotEmpty
                            ? campaign.subtitle
                            : 'Get items worth a fortune for just ${campaign.entryPriceCoins} coin${campaign.entryPriceCoins == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Simply select a product below and purchase it for ${campaign.entryPriceCoins} coin${campaign.entryPriceCoins == 1 ? '' : 's'} to get a chance to win.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      prizesAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => Text('Error loading prizes: $e'),
                        data: (prizes) {
                          if (prizes.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text('No prizes in this campaign yet.'),
                              ),
                            );
                          }
                          return Column(
                            children: prizes
                                .map(
                                  (prize) => RupeeGamePrizeCard(
                                    prize: prize,
                                    entryPriceCoins: campaign.entryPriceCoins,
                                    alreadyEntered: enteredPrizeIds.contains(
                                      prize.id,
                                    ),
                                    isLoading: _buyingPrizeId == prize.id,
                                    onBuy: () =>
                                        _onBuy(prize, campaign.entryPriceCoins),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
