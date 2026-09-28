import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/agency_center_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class AgencyApplicationRecordScreen extends ConsumerStatefulWidget {
  const AgencyApplicationRecordScreen({
    super.key,
    required this.agencyId,
    this.initialTab = 0,
  });

  final String agencyId;
  final int initialTab;

  @override
  ConsumerState<AgencyApplicationRecordScreen> createState() =>
      _AgencyApplicationRecordScreenState();
}

class _AgencyApplicationRecordScreenState
    extends ConsumerState<AgencyApplicationRecordScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _handle(
    String applicationId,
    String userId,
    bool approve,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      if (approve) {
        await supabase.from('agency_members').insert({
          'agency_id': widget.agencyId,
          'user_id': userId,
          'role': 'host',
        });
        await supabase
            .from('agency_applications')
            .update({'status': 'approved'})
            .eq('id', applicationId);
      } else {
        await supabase
            .from('agency_applications')
            .update({'status': 'rejected'})
            .eq('id', applicationId);
      }
      ref.invalidate(
        agencyApplicationsProvider((
          agencyId: widget.agencyId,
          status: 'pending',
        )),
      );
      ref.invalidate(
        agencyApplicationsProvider((
          agencyId: widget.agencyId,
          status: 'approved',
        )),
      );
      ref.invalidate(
        agencyApplicationsProvider((
          agencyId: widget.agencyId,
          status: 'rejected',
        )),
      );
      ref.invalidate(agencyMembersProvider(widget.agencyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Request Approved' : 'Request Rejected'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error processing request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Application Record',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white38,
          indicatorColor: Colors.tealAccent,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
            Tab(text: 'Left / Removed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AppList(
            status: 'pending',
            agencyId: widget.agencyId,
            onAction: _handle,
          ),
          _AppList(status: 'approved', agencyId: widget.agencyId),
          _AppList(status: 'rejected', agencyId: widget.agencyId),
          _ExitList(agencyId: widget.agencyId),
        ],
      ),
    );
  }
}

class _AppList extends ConsumerWidget {
  const _AppList({required this.status, required this.agencyId, this.onAction});

  final String status;
  final String agencyId;
  final Future<void> Function(String, String, bool)? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      agencyApplicationsProvider((agencyId: agencyId, status: status)),
    );

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => asyncErrorWidget(e),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text(
              'No $status records',
              style: const TextStyle(color: Colors.white24),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final req = rows[i];
            final user = req['users'] as Map<String, dynamic>?;
            final created = DateTime.tryParse(
              req['created_at']?.toString() ?? '',
            );
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: user?['avatar_url'] != null
                            ? CachedNetworkImageProvider(
                                user!['avatar_url'].toString(),
                              )
                            : null,
                        child: user?['avatar_url'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?['username']?.toString() ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (created != null)
                              Text(
                                DateFormat(
                                  'yyyy-MM-dd HH:mm',
                                ).format(created.toLocal()),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        status,
                        style: TextStyle(
                          color: status == 'pending'
                              ? Colors.orangeAccent
                              : status == 'approved'
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (status == 'pending' && onAction != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onAction!(
                              req['id'].toString(),
                              user?['id']?.toString() ?? '',
                              false,
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => onAction!(
                              req['id'].toString(),
                              user?['id']?.toString() ?? '',
                              true,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ExitList extends ConsumerWidget {
  const _ExitList({required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(agencyMemberEventsProvider(agencyId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => asyncErrorWidget(e),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(
            child: Text(
              'No left / removed records yet',
              style: TextStyle(color: Colors.white24),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            final user = row['users'] as Map<String, dynamic>?;
            final actor = row['actor'] as Map<String, dynamic>?;
            final type = row['event_type']?.toString() ?? 'left';
            final isRemoved = type == 'removed';
            final created = DateTime.tryParse(
              row['created_at']?.toString() ?? '',
            );
            final actorName = actor?['username']?.toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: user?['avatar_url'] != null
                        ? CachedNetworkImageProvider(
                            user!['avatar_url'].toString(),
                          )
                        : null,
                    child: user?['avatar_url'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?['username']?.toString() ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isRemoved
                              ? (actorName != null
                                    ? 'Removed by $actorName'
                                    : 'Removed by agency')
                              : 'Left the agency',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        if (created != null)
                          Text(
                            DateFormat(
                              'yyyy-MM-dd HH:mm',
                            ).format(created.toLocal()),
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isRemoved ? Colors.redAccent : Colors.orangeAccent)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isRemoved ? 'Removed' : 'Left',
                      style: TextStyle(
                        color: isRemoved
                            ? Colors.redAccent
                            : Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
