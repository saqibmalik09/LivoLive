import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/staff_provider.dart';
import 'package:sk_live/core/providers/salary_provider.dart';
import 'package:sk_live/core/providers/staff_portal_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/features/home/presentation/pages/agency_center_screen.dart';
import 'package:sk_live/features/home/presentation/widgets/staff_portal_charts.dart';
import 'package:sk_live/features/home/presentation/widgets/staff_portal_kpi_cards.dart';
import 'package:sk_live/features/home/presentation/widgets/staff_portal_mock.dart';

class StaffCenterScreen extends ConsumerStatefulWidget {
  const StaffCenterScreen({super.key});

  @override
  ConsumerState<StaffCenterScreen> createState() => _StaffCenterScreenState();
}

class _StaffCenterScreenState extends ConsumerState<StaffCenterScreen> {
  bool _isLoading = true;
  BusinessStaffProfile? _staff;
  bool _ownsAgency = false;

  final TextEditingController _vipSearchController = TextEditingController();
  List<Map<String, dynamic>> _vipSearchResults = [];
  String? _vipSelectedUserId;
  int _vipSelectedLevel = 1;
  bool _vipWorking = false;

  static const _bg = Color(0xFF0F0F1A);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final staff = await ref.read(myBusinessStaffProvider.future);
    final owned = await StaffActions.getMyOwnedAgency();
    if (mounted) {
      setState(() {
        _staff = staff;
        _ownsAgency = owned != null;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    ref.invalidate(staffPortalHierarchyProvider);
    ref.invalidate(staffPortalChartsProvider);
    final staff = _staff;
    if (staff != null) {
      ref.invalidate(staffTeamProvider(staff.id));
      ref.invalidate(staffAgencyApplicationsProvider(staff.id));
      ref.invalidate(staffEarningsProvider(staff));
    }
    ref.invalidate(mySalaryPayoutsProvider);
    await _load();
    await ref.read(staffPortalHierarchyProvider.future);
    await ref.read(staffPortalChartsProvider.future);
  }

  Future<void> _vipSearch() async {
    final q = _vipSearchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _vipSearchResults = [];
        _vipSelectedUserId = null;
      });
      return;
    }

    final results = await StaffActions.searchUsers(q);
    if (!mounted) return;
    setState(() {
      _vipSearchResults = results;
      _vipSelectedUserId = results.isNotEmpty
          ? results.first['id']?.toString()
          : null;
      _vipSelectedLevel = 1;
    });
  }

  Future<void> _vipApply() async {
    final targetUserId = _vipSelectedUserId;
    if (targetUserId == null || targetUserId.isEmpty) return;

    setState(() => _vipWorking = true);
    final vipLevel = _vipSelectedLevel;

    final res = vipLevel == 0
        ? await StaffActions.removeVipForUser(targetUserId: targetUserId)
        : await StaffActions.setVipForUser(
            targetUserId: targetUserId,
            vipLevel: vipLevel,
          );

    if (!mounted) return;
    setState(() => _vipWorking = false);

    final ok = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? vipLevel == 0
                    ? 'VIP removed'
                    : 'VIP level $vipLevel granted (30 days)'
              : res['message']?.toString() ?? context.l10n.common_failed,
        ),
      ),
    );

    if (!ok) return;

    setState(() {
      _vipSearchResults = [];
      _vipSelectedUserId = null;
      _vipSelectedLevel = 1;
      _vipSearchController.clear();
    });
    _refreshAll();
  }

  Future<void> _createAgency() async {
    final controller = TextEditingController(text: 'My Agency');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          context.l10n.agency_createAgency,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Agency name',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.common_create),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final res = await StaffActions.createOwnAgency(name);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agency created. Code: ${res['agency_code']}')),
      );
      _refreshAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ?? context.l10n.common_failed,
          ),
        ),
      );
    }
  }

  Future<void> _createAgencyForUserUnderBd() async {
    final ownerCtrl = TextEditingController();
    final bdCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Create Agency under BD',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Only creates a new agency for a User ID. Cannot attach someone else\'s agency.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ownerCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Owner User ID',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bdCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'BD ID (staff code)',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.common_create),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final owner = ownerCtrl.text.trim();
    final bd = bdCtrl.text.trim();
    if (owner.isEmpty || bd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner User ID and BD ID required')),
      );
      return;
    }

    final res = await StaffActions.createAgencyForOwnerUnderBd(
      ownerUserId: owner,
      bdRef: bd,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      final code = res['agency_code']?.toString();
      final created = res['created'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created
                ? 'Agency created (code $code) under BD'
                : res['message']?.toString() ?? 'Agency under BD (code $code)',
          ),
        ),
      );
      _refreshAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ?? context.l10n.common_failed,
          ),
        ),
      );
    }
  }

  Future<void> _deactivateStaff(String staffId, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          context.l10n.agency_removeStaff,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Deactivate $label? They will no longer appear as active staff.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await StaffActions.deactivateStaff(staffId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['success'] == true
              ? 'Staff removed'
              : res['message']?.toString() ?? context.l10n.common_failed,
        ),
      ),
    );
    if (res['success'] == true) _refreshAll();
  }

  Future<void> _deactivateAgency(String agencyId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Deactivate agency?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Deactivate "$name"? Hosts stay linked historically but new joins are blocked.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Deactivate',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await StaffActions.deactivateAgency(agencyId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['success'] == true
              ? 'Agency deactivated'
              : res['message']?.toString() ?? 'Failed',
        ),
      ),
    );
    if (res['success'] == true) _refreshAll();
  }

  Future<void> _createSubStaff(String role) async {
    final staff = _staff;
    if (staff == null) return;
    final normalized = role == 'bd_admin' ? 'county_admin' : role;
    if (normalized != 'county_admin' &&
        normalized != 'bd' &&
        normalized != 'assistant' &&
        normalized != 'customer_service') {
      return;
    }

    final queryController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    String? selectedUserId;
    final roleLabel = normalized == 'county_admin'
        ? 'County Admin'
        : normalized == 'assistant'
        ? 'Assistant'
        : normalized == 'customer_service'
        ? 'Customer Service'
        : 'BD';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: Text(
              'Create $roleLabel',
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: queryController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Search username or short ID',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final users = await StaffActions.searchUsers(
                        queryController.text,
                      );
                      setDialogState(() => results = users);
                    },
                    child: const Text('Search'),
                  ),
                  ...results.map(
                    (user) => RadioListTile<String>(
                      value: user['id'] as String,
                      groupValue: selectedUserId,
                      onChanged: (v) =>
                          setDialogState(() => selectedUserId = v),
                      title: Text(
                        user['username']?.toString() ?? 'User',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'ID ${user['short_id']}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: selectedUserId == null
                    ? null
                    : () async {
                        final res = await StaffActions.createSubStaff(
                          parentStaffId: staff.id,
                          targetUserId: selectedUserId!,
                          role: normalized,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res['success'] == true
                                    ? '$roleLabel created. Code: ${res['staff_code']}'
                                    : res['message']?.toString() ?? 'Failed',
                              ),
                            ),
                          );
                          ref.invalidate(staffTeamProvider(staff.id));
                          ref.invalidate(staffPortalHierarchyProvider);
                          ref.invalidate(staffPortalChartsProvider);
                        }
                      },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final staff = _staff;
    if (staff == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(context.l10n.staff_centerTitle),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(
          child: Text(
            'No active staff role found.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final hierarchyAsync = ref.watch(staffPortalHierarchyProvider);
    final chartsAsync = ref.watch(staffPortalChartsProvider);
    final teamAsync = ref.watch(staffTeamProvider(staff.id));
    final appsAsync = ref.watch(staffAgencyApplicationsProvider(staff.id));
    final salaryPayoutsAsync = ref.watch(mySalaryPayoutsProvider);

    final title = staff.role == 'super_bd'
        ? 'Super Admin Center'
        : '${staff.roleLabel} Center';

    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFFA855F7),
          surface: Color(0xFF1A1A2E),
          onSurface: Colors.white,
          onPrimary: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white70,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          subtitleTextStyle: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          labelStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          secondaryLabelStyle: const TextStyle(color: Colors.white),
          side: BorderSide(color: Colors.amber.withValues(alpha: 0.45)),
          selectedColor: Colors.amber.withValues(alpha: 0.25),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        dividerColor: Colors.white12,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: RefreshIndicator(
          color: Colors.amber,
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _buildHero(staff, hierarchyAsync),
              const SizedBox(height: 16),
              hierarchyAsync.when(
                data: (h) {
                  final charts = chartsAsync.valueOrNull;
                  final useMock = charts == null
                      ? StaffPortalMock.shouldUseMock(
                          h.stats,
                          StaffPortalCharts.fromHierarchy(h),
                        )
                      : StaffPortalMock.shouldUseMock(h.stats, charts);
                  final stats = useMock ? StaffPortalMock.stats : h.stats;
                  return Column(
                    children: [
                      StaffPortalKpiCards(stats: stats, role: staff.role),
                      const SizedBox(height: 12),
                      StaffPortalEarningsStrip(
                        commission: stats.commissionDiamonds,
                        salary: stats.salaryDiamonds,
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  ),
                ),
                error: (e, _) => _errorBox(e),
              ),
              const SizedBox(height: 16),
              chartsAsync.when(
                data: (c) {
                  final hier = hierarchyAsync.valueOrNull;
                  final useMock = hier == null
                      ? StaffPortalMock.shouldUseMock(StaffPortalStats.empty, c)
                      : StaffPortalMock.shouldUseMock(hier.stats, c);
                  final charts = useMock ? StaffPortalMock.charts : c;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StaffCommissionTrendChart(points: charts.commissionTrend),
                      const SizedBox(height: 12),
                      StaffAgencyBarsChart(agencies: charts.agencyPerformance),
                      const SizedBox(height: 12),
                      StaffRoleBreakdownChips(rows: charts.roleBreakdown),
                      const SizedBox(height: 16),
                      _sectionTitle(context.l10n.agency_topHosts),
                      const SizedBox(height: 8),
                      if (charts.topHosts.isEmpty)
                        const Text(
                          'No host stats yet.',
                          style: TextStyle(color: Colors.white60),
                        )
                      else
                        ...charts.topHosts.take(8).map(_topHostTile),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => _errorBox(e),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (staff.normalizedRole == 'super_bd') ...[
                    _actionChip(
                      'Create County Admin',
                      Iconsax.crown_1,
                      () => _createSubStaff('county_admin'),
                    ),
                    _actionChip(
                      'Create BD',
                      Iconsax.people,
                      () => _createSubStaff('bd'),
                    ),
                    _actionChip(
                      'Create Assistant',
                      Iconsax.user,
                      () => _createSubStaff('assistant'),
                    ),
                    _actionChip(
                      'Create CS',
                      Iconsax.headphone,
                      () => _createSubStaff('customer_service'),
                    ),
                  ] else if (staff.childRole != null)
                    _actionChip(
                      'Create ${staff.childRole == 'bd' ? 'BD' : 'Team Member'}',
                      Iconsax.people,
                      () => _createSubStaff(staff.childRole!),
                    ),
                  if (staff.normalizedRole == 'super_bd' ||
                      staff.normalizedRole == 'county_admin')
                    _actionChip(
                      'Create Agency for User',
                      Iconsax.building,
                      _createAgencyForUserUnderBd,
                    ),
                  if (!_ownsAgency && staff.normalizedRole != 'county_admin')
                    _actionChip(
                      'Create My Agency',
                      Iconsax.building_4,
                      _createAgency,
                    )
                  else if (_ownsAgency)
                    _actionChip(
                      context.l10n.agency_centerTitle,
                      Iconsax.status_up,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AgencyCenterScreen(),
                          ),
                        );
                      },
                    ),
                ],
              ),
              if (staff.normalizedRole == 'super_bd') ...[
                const SizedBox(height: 24),
                _sectionTitle('VIP Grant (30 days)'),
                const SizedBox(height: 8),
                _vipGrantSection(),
                const SizedBox(height: 24),
              ],
              _sectionTitle('Salary history'),
              const SizedBox(height: 8),
              salaryPayoutsAsync.when(
                data: (rows) {
                  final chainRows = rows
                      .where((r) => r['beneficiary_role'] != 'host')
                      .toList();
                  if (chainRows.isEmpty) {
                    return const Text(
                      'No past periods yet. Paid salary for your role stays listed after rollover.',
                      style: TextStyle(color: Colors.white60),
                    );
                  }
                  return Column(
                    children: chainRows.take(20).map((r) {
                      final role = r['beneficiary_role']?.toString() ?? '';
                      final status = r['status']?.toString() ?? 'paid';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r['period_id']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$role · $status',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '+${r['total_amount']}',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Pending agency applications'),
              const SizedBox(height: 8),
              appsAsync.when(
                data: (apps) {
                  if (apps.isEmpty) {
                    return const Text(
                      'No pending applications.',
                      style: TextStyle(color: Colors.white60),
                    );
                  }
                  return Column(
                    children: apps.map((app) {
                      final user = app['users'] as Map<String, dynamic>?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user?['avatar_url'] != null
                                  ? CachedNetworkImageProvider(
                                      user!['avatar_url'],
                                    )
                                  : null,
                              child: user?['avatar_url'] == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                              user?['username']?.toString() ?? 'Applicant',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              app['real_name']?.toString() ?? '',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.greenAccent,
                                  ),
                                  onPressed: () async {
                                    final res =
                                        await StaffActions.approveAgencyApplication(
                                          app['id'],
                                        );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          res['success'] == true
                                              ? 'Approved. Code: ${res['agency_code']}'
                                              : res['message']?.toString() ??
                                                    'Failed',
                                        ),
                                      ),
                                    );
                                    ref.invalidate(
                                      staffAgencyApplicationsProvider(staff.id),
                                    );
                                    ref.invalidate(
                                      staffPortalHierarchyProvider,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    await StaffActions.rejectAgencyApplication(
                                      app['id'],
                                    );
                                    ref.invalidate(
                                      staffAgencyApplicationsProvider(staff.id),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                ),
                error: (e, _) => asyncErrorWidget(e),
              ),
              const SizedBox(height: 24),
              _sectionTitle('My team'),
              const SizedBox(height: 8),
              teamAsync.when(
                data: (team) {
                  if (team.isEmpty) {
                    return const Text(
                      'No team members yet.',
                      style: TextStyle(color: Colors.white60),
                    );
                  }
                  return Column(
                    children: team.map((member) {
                      final user = member['users'] as Map<String, dynamic>?;
                      final role = member['role']?.toString() ?? '';
                      final roleLabel = role == 'super_bd'
                          ? 'Super Admin'
                          : role == 'bd_admin' || role == 'county_admin'
                          ? 'County Admin'
                          : role == 'bd'
                          ? 'BD'
                          : role == 'assistant'
                          ? 'Assistant'
                          : role == 'customer_service'
                          ? 'Customer Service'
                          : role;
                      final name = user?['username']?.toString() ?? 'Member';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user?['avatar_url'] != null
                                  ? CachedNetworkImageProvider(
                                      user!['avatar_url'],
                                    )
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '$roleLabel · ${member['staff_code']}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                ),
                error: (e, _) => asyncErrorWidget(e),
              ),
              if (staff.normalizedRole == 'super_bd') ...[
                const SizedBox(height: 24),
                _sectionTitle('Network BDs & County Admins'),
                const SizedBox(height: 8),
                hierarchyAsync.when(
                  data: (h) {
                    final removable = h.treeStaff.where((s) {
                      final r = s['role']?.toString() ?? '';
                      final active = s['is_active'] != false;
                      return active &&
                          (r == 'bd' || r == 'county_admin' || r == 'bd_admin');
                    }).toList();
                    if (removable.isEmpty) {
                      return const Text(
                        'No BDs or County Admins in your network.',
                        style: TextStyle(color: Colors.white60),
                      );
                    }
                    return Column(
                      children: removable.map((member) {
                        final role = member['role']?.toString() ?? '';
                        final roleLabel = role == 'bd' ? 'BD' : 'County Admin';
                        final name = member['username']?.toString() ?? 'Member';
                        final id = member['id']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '$roleLabel · ${member['staff_code']}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              trailing: id.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Remove',
                                      onPressed: () => _deactivateStaff(
                                        id,
                                        '$roleLabel $name',
                                      ),
                                    ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                _sectionTitle('Network agencies'),
                const SizedBox(height: 8),
                hierarchyAsync.when(
                  data: (h) {
                    final agencies = h.treeAgencies
                        .where((a) => a['is_active'] != false)
                        .toList();
                    if (agencies.isEmpty) {
                      return const Text(
                        'No agencies in your network.',
                        style: TextStyle(color: Colors.white60),
                      );
                    }
                    return Column(
                      children: agencies.map((a) {
                        final name = a['name']?.toString() ?? 'Agency';
                        final code = a['agency_code']?.toString() ?? '';
                        final id = a['id']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: const Icon(
                                Iconsax.building,
                                color: Colors.greenAccent,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                code,
                                style: const TextStyle(color: Colors.white54),
                              ),
                              trailing: id.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Deactivate',
                                      onPressed: () =>
                                          _deactivateAgency(id, name),
                                    ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _vipGrantSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _vipSearchController,
            enabled: !_vipWorking,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Search user (username or short ID)',
              labelStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.amber),
              ),
            ),
            onSubmitted: (_) {
              _vipSearch();
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _vipWorking
                      ? null
                      : () {
                          _vipSearch();
                        },
                  child: const Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _vipSelectedLevel,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  onChanged: _vipWorking
                      ? null
                      : (v) => setState(() => _vipSelectedLevel = v ?? 1),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Remove VIP')),
                    DropdownMenuItem(value: 1, child: Text('VIP 1')),
                    DropdownMenuItem(value: 2, child: Text('VIP 2')),
                    DropdownMenuItem(value: 3, child: Text('VIP 3')),
                    DropdownMenuItem(value: 4, child: Text('VIP 4')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_vipSearchResults.isNotEmpty)
            ..._vipSearchResults.map((u) {
              final id = u['id']?.toString() ?? '';
              final username = u['username']?.toString() ?? 'User';
              final shortId = u['short_id']?.toString() ?? '';
              return RadioListTile<String>(
                value: id,
                groupValue: _vipSelectedUserId,
                onChanged: _vipWorking
                    ? null
                    : (v) => setState(() => _vipSelectedUserId = v),
                activeColor: Colors.amber,
                title: Text(
                  username,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'ID $shortId',
                  style: const TextStyle(color: Colors.white54),
                ),
              );
            }).toList(),
          if (_vipSearchResults.isNotEmpty) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_vipWorking || _vipSelectedUserId == null)
                  ? null
                  : () {
                      _vipApply();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _vipSelectedLevel == 0
                    ? 'Remove VIP'
                    : 'Apply VIP $_vipSelectedLevel',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(
    BusinessStaffProfile staff,
    AsyncValue<StaffPortalHierarchy> hierarchyAsync,
  ) {
    final period = hierarchyAsync.valueOrNull?.periodId ?? '';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D1B4E), Color(0xFF1A0A2E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            staff.roleLabel,
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (period.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Period $period',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Staff Code: ',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                staff.staffCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: staff.staffCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Staff code copied')),
                  );
                },
                icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topHostTile(Map<String, dynamic> host) {
    final username = host['username']?.toString() ?? 'Host';
    final agency = host['agency_name']?.toString() ?? '—';
    final diamonds =
        (host['charm'] as num?)?.toInt() ??
        (host['diamonds'] as num?)?.toInt() ??
        0;
    final days = (host['valid_days'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$agency · $days valid days',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${formatStaffCompact(diamonds)} Charm',
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _vipSearchController.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Colors.white,
      ),
    );
  }

  Widget _errorBox(Object error) {
    if (shouldHideErrorFromUsers(error)) {
      debugPrint('Staff center suppressed error: $error');
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Unable to load. Pull down to refresh.',
        style: TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _actionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: Colors.amber),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: const Color(0xFF252540),
      side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
      onPressed: onTap,
    );
  }
}
