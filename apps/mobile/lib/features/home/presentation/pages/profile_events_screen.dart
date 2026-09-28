import 'package:flutter/material.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/home/presentation/widgets/party_events_tab.dart';

class ProfileEventsScreen extends StatelessWidget {
  const ProfileEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        title: Text(
          context.l10n.events_title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: const PartyEventsTab(),
    );
  }
}
