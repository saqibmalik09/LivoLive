import 'package:flutter/material.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/widgets/party_screen_background.dart';

class MessageFlowBackground extends StatelessWidget {
  const MessageFlowBackground({super.key});

  static const Color fallbackColor = AppColors.partyPageBg;

  @override
  Widget build(BuildContext context) {
    return const PartyScreenBackground();
  }
}

class MessageFlowScaffold extends StatelessWidget {
  const MessageFlowScaffold({super.key, this.appBar, required this.body});

  final PreferredSizeWidget? appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: appBar != null,
      backgroundColor: MessageFlowBackground.fallbackColor,
      appBar: appBar,
      body: Stack(
        fit: StackFit.expand,
        children: [const MessageFlowBackground(), body],
      ),
    );
  }
}
