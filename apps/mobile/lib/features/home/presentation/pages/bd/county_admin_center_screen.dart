import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/bd_center_provider.dart';
import 'package:sk_live/core/providers/staff_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class CountyAdminCenterScreen extends ConsumerStatefulWidget {
  const CountyAdminCenterScreen({super.key});

  @override
  ConsumerState<CountyAdminCenterScreen> createState() =>
      _CountyAdminCenterScreenState();
}

class _CountyAdminCenterScreenState
    extends ConsumerState<CountyAdminCenterScreen> {
  final _adminCode = TextEditingController();
  final _userQuery = TextEditingController();
  final _bdCode = TextEditingController();
  final _agencyId = TextEditingController();
  bool _busy = false;
  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;

  @override
  void dispose() {
    _adminCode.dispose();
    _userQuery.dispose();
    _bdCode.dispose();
    _agencyId.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final rows = await StaffActions.searchUsers(_userQuery.text);
    if (mounted) setState(() => _users = rows);
  }

  Future<void> _activateBd() async {
    if (_selectedUserId == null || _adminCode.text.trim().isEmpty) {
      _toast('Select user + enter your Admin ID');
      return;
    }
    setState(() => _busy = true);
    final res = await BdCenterActions.activateBd(
      targetUserId: _selectedUserId!,
      adminStaffCode: _adminCode.text.trim(),
    );
    setState(() => _busy = false);
    _toast(
      res['success'] == true
          ? 'BD activated. Code: ${res['staff_code']}'
          : res['message']?.toString() ?? 'Failed',
    );
    if (res['success'] == true) {
      ref.invalidate(countyAdminCenterProvider);
    }
  }

  Future<void> _activateAgency() async {
    if (_agencyId.text.trim().isEmpty ||
        _bdCode.text.trim().isEmpty ||
        _adminCode.text.trim().isEmpty) {
      _toast('Agency ID, BD ID, and Admin ID required');
      return;
    }
    setState(() => _busy = true);
    final res = await BdCenterActions.activateAgency(
      agencyRef: _agencyId.text.trim(),
      bdStaffCode: _bdCode.text.trim(),
      adminStaffCode: _adminCode.text.trim(),
    );
    setState(() => _busy = false);
    if (res['success'] == true) {
      final code = res['agency_code']?.toString();
      final created = res['created'] == true;
      _toast(
        created
            ? 'Agency created for user (code $code) under BD'
            : 'Agency activated under BD${code != null ? ' (code $code)' : ''}',
      );
      ref.invalidate(countyAdminCenterProvider);
    } else {
      _toast(res['message']?.toString() ?? 'Failed');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(countyAdminCenterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'County Admin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            asyncErrorWidget(e, style: const TextStyle(color: Colors.white54)),
        data: (data) {
          if (data == null) {
            return const Center(
              child: Text(
                'County Admin access required',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          final staff = Map<String, dynamic>.from(data['staff'] as Map);
          final bds = (data['bds'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final agencies = (data['agencies'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          if (_adminCode.text.isEmpty) {
            _adminCode.text = staff['staff_code']?.toString() ?? '';
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Your Admin ID: ${staff['staff_code']}',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Users must use your Admin ID when you activate BD / agency for your team.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 20),
              _section('Activate BD'),
              TextField(
                controller: _adminCode,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Your Admin ID'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userQuery,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('Search user ID / name'),
                    ),
                  ),
                  IconButton(
                    onPressed: _searchUsers,
                    icon: const Icon(Icons.search, color: Colors.white),
                  ),
                ],
              ),
              ..._users.map(
                (u) => RadioListTile<String>(
                  value: u['id'].toString(),
                  groupValue: _selectedUserId,
                  onChanged: (v) => setState(() => _selectedUserId = v),
                  title: Text(
                    '${u['username']} (${u['short_id']})',
                    style: const TextStyle(color: Colors.white),
                  ),
                  activeColor: Colors.purpleAccent,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _activateBd,
                child: const Text('Activate BD'),
              ),
              const SizedBox(height: 28),
              _section('Create Agency under BD'),
              const Text(
                'Only creates a new agency for a User ID under your BD. Cannot attach someone else\'s agency.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _agencyId,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Owner User ID'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bdCode,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('BD ID (staff code)'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _activateAgency,
                child: Text(context.l10n.agency_createAgency),
              ),
              const SizedBox(height: 28),
              _section('Team BDs (${bds.length})'),
              ...bds.map(
                (b) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    b['username']?.toString() ?? 'BD',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'BD ID ${b['staff_code']}',
                    style: const TextStyle(color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _section('Team Agencies (${agencies.length})'),
              ...agencies.map(
                (a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    a['name']?.toString() ?? 'Agency',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Code ${a['agency_code']} · BD ${a['bd_code']}',
                    style: const TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    ),
  );

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white54),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.purpleAccent),
    ),
  );
}
