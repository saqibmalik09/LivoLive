import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/agency_center_provider.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_admin_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_application_record_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_data_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_host_list_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_host_management_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_information_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_menu_tile.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_notice_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_period_salary_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency_payment_methods_screen.dart';
import 'package:sk_live/features/home/presentation/pages/host_center_screen.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class AgencyCenterScreen extends ConsumerWidget {
  const AgencyCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessAsync = ref.watch(agencyCenterAccessProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          accessAsync.valueOrNull?.agency['name']?.toString() ??
              context.l10n.agency_centerTitle,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
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
      ),
      body: accessAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => asyncErrorWidget(e),
        data: (access) {
          if (access == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No agency access. Only owners and agency admins can open Agency Center.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            );
          }
          return _AgencyHubBody(access: access);
        },
      ),
    );
  }
}

class _AgencyHubBody extends StatelessWidget {
  const _AgencyHubBody({required this.access});

  final AgencyCenterAccess access;

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final agency = access.agency;
    final code = agency['agency_code']?.toString() ?? '------';
    final items = <({IconData icon, String label, Widget page})>[
      (icon: Iconsax.chart_2, label: 'My Data', page: const HostCenterScreen()),
      (
        icon: Iconsax.diagram,
        label: 'Agency Data',
        page: AgencyDataScreen(agencyId: access.agencyId),
      ),
      (
        icon: Iconsax.wallet_money,
        label: 'Period Salary',
        page: AgencyPeriodSalaryScreen(agencyId: access.agencyId),
      ),
      (
        icon: Iconsax.people,
        label: 'Host List',
        page: AgencyHostListScreen(agencyId: access.agencyId),
      ),
      (
        icon: Iconsax.setting_2,
        label: 'Host management',
        page: AgencyHostManagementScreen(
          agencyId: access.agencyId,
          agencyCode: code,
        ),
      ),
      (
        icon: Iconsax.shield_tick,
        label: 'Information',
        page: AgencyInformationScreen(
          agencyId: access.agencyId,
          canEdit: true,
          initialName: agency['name']?.toString() ?? '',
          initialAnnouncement: agency['announcement']?.toString() ?? '',
          initialLogoUrl: agency['logo_url']?.toString(),
          initialAttribute: agency['attribute']?.toString() ?? 'Personal',
          initialWhatsapp: agency['whatsapp']?.toString() ?? '',
          initialEmail: agency['contact_email']?.toString() ?? '',
        ),
      ),
      (
        icon: Iconsax.document_text,
        label: 'Application Record',
        page: AgencyApplicationRecordScreen(agencyId: access.agencyId),
      ),
      (
        icon: Iconsax.notification,
        label: 'Notice',
        page: AgencyNoticeScreen(agencyId: access.agencyId),
      ),
      (
        icon: Iconsax.user_edit,
        label: 'Agency Admin',
        page: AgencyAdminScreen(
          agencyId: access.agencyId,
          ownerId: agency['owner_id']?.toString() ?? '',
          canChangeRoles: access.canChangeRoles,
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      access.isOwner ? 'Owner' : 'Admin',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code $code',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Agency Code copied!')),
                  );
                },
                icon: const Icon(Iconsax.copy, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 6,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, i) {
            final item = items[i];
            return AgencyMenuTile(
              icon: item.icon,
              label: item.label,
              onTap: () => _open(context, item.page),
            );
          },
        ),
        if (access.canManagePayment) ...[
          const SizedBox(height: 20),
          Material(
            color: const Color(0xFFF7F7F9),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgencyPaymentMethodsScreen(
                      agencyId: access.agencyId,
                      currentDetails: agency['payment_details'] is List
                          ? agency['payment_details'] as List
                          : const [],
                    ),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(Iconsax.wallet_3, color: Color(0xFF4C8DFF)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Payment Methods',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
