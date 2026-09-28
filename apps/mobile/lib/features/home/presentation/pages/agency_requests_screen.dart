import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/theme/app_colors.dart';

class AgencyRequestsScreen extends ConsumerStatefulWidget {
  final String agencyId;
  const AgencyRequestsScreen({super.key, required this.agencyId});

  @override
  ConsumerState<AgencyRequestsScreen> createState() =>
      _AgencyRequestsScreenState();
}

class _AgencyRequestsScreenState extends ConsumerState<AgencyRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('agency_applications')
          .select('*, users:user_id(username, avatar_url, id)')
          .eq('agency_id', widget.agencyId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(
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

      _fetchRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Request Approved' : 'Request Rejected'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling request: $e');
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
        elevation: 0,
        title: const Text(
          'Join Requests',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? const Center(
              child: Text(
                'No pending requests',
                style: TextStyle(color: Colors.white24),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                final user = req['users'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: user['avatar_url'] != null
                                ? CachedNetworkImageProvider(user['avatar_url'])
                                : null,
                            child: user['avatar_url'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['username'] ?? 'User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Applied on: ${req['created_at'].toString().substring(0, 10)}',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _handleAction(req['id'], user['id'], false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withValues(
                                  alpha: 0.1,
                                ),
                                foregroundColor: Colors.redAccent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _handleAction(req['id'], user['id'], true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
