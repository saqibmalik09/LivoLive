import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/core/providers/bottom_nav_config_provider.dart';
import 'package:sk_live/core/providers/navigation_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/widgets/user_profile_mini_sheet.dart';
import 'package:sk_live/features/home/presentation/pages/agency_center_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency_profile_screen.dart';
import 'package:sk_live/features/home/presentation/pages/host_center_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NavigationUtils {
  static void navigateToProfile(
    BuildContext context,
    WidgetRef ref,
    String targetUserId, {
    bool openFull = false,
  }) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (targetUserId == currentUserId) {
      ref.read(bottomNavIndexProvider.notifier).state = bottomNavIndexForKey(
        'my',
      );

      while (context.canPop()) {
        context.pop();
      }

      context.go(AppRouter.home);
      return;
    }

    if (openFull) {
      context.push(AppRouter.userProfile, extra: targetUserId);
      return;
    }

    UserProfileMiniSheet.show(context, targetUserId);
  }

  static Future<void> navigateToAgency(
    BuildContext context, {
    required String agencyId,
  }) async {
    final id = agencyId.trim();
    if (id.isEmpty) return;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    Widget page = AgencyProfileScreen(agencyId: id);

    if (userId != null) {
      try {
        final owned = await supabase
            .from('agencies')
            .select('id')
            .eq('id', id)
            .eq('owner_id', userId)
            .maybeSingle();

        final member = await supabase
            .from('agency_members')
            .select('id, role')
            .eq('agency_id', id)
            .eq('user_id', userId)
            .maybeSingle();

        if (owned != null) {
          page = const AgencyCenterScreen();
        } else if (member != null) {
          final role = member['role']?.toString().toLowerCase() ?? '';
          if (role == 'admin' || role == 'owner') {
            page = const AgencyCenterScreen();
          } else {
            page = const HostCenterScreen();
          }
        }
      } catch (_) {}
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
