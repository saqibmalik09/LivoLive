import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/cp_nest_provider.dart';

class CPUserSearchScreen extends ConsumerStatefulWidget {
  final CPNestItemModel item;
  const CPUserSearchScreen({super.key, required this.item});

  @override
  ConsumerState<CPUserSearchScreen> createState() => _CPUserSearchScreenState();
}

class _CPUserSearchScreenState extends ConsumerState<CPUserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isSending = false;

  Future<void> _sendProposal(String receiverId, String username) async {
    setState(() => _isSending = true);
    try {
      await CPNestActions.sendProposal(
        itemId: widget.item.id,
        price: widget.item.price,
        receiverId: receiverId,
      );
      if (mounted) {
        _showSuccessDialog(username);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSuccessDialog(String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: Colors.pinkAccent, size: 60),
            const SizedBox(height: 15),
            const Text(
              'Proposal Sent!',
              style: TextStyle(
                color: Colors.pinkAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your CP proposal has been sent to $username. They have 24 hours to accept.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Great!',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(cpNestUserSearchProvider(_query));

    return Scaffold(
      backgroundColor: const Color(0xFFFDEFF4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.pinkAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Recipient',
          style: const TextStyle(
            color: Colors.pinkAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _query = val),
                decoration: const InputDecoration(
                  hintText: 'Search by name or ID...',
                  hintStyle: TextStyle(color: Colors.pinkAccent, fontSize: 14),
                  prefixIcon: Icon(
                    Iconsax.search_normal,
                    color: Colors.pinkAccent,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              _query.isEmpty ? 'Recommended VIPs' : 'Search Results',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          Expanded(
            child: usersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.pinkAccent),
              ),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (users) {
                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(color: Colors.black38),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _buildVIPUserTile(user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVIPUserTile(Map<String, dynamic> user) {
    final int level = user['user_level'] ?? 1;
    final bool isTopVIP = level > 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isTopVIP
                ? Colors.amber.withOpacity(0.1)
                : Colors.pink.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isTopVIP
            ? Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isTopVIP ? Colors.amber : Colors.pinkAccent,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundImage: user['avatar_url'] != null
                  ? NetworkImage(user['avatar_url'])
                  : null,
              child: user['avatar_url'] == null
                  ? const Icon(Icons.person)
                  : null,
            ),
          ),
          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user['username'] ?? context.l10n.common_user,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isTopVIP
                              ? [Colors.amber, Colors.orange]
                              : [Colors.pinkAccent, Colors.pink],
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Lv.$level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 8),
                    const SizedBox(width: 4),
                    const Text(
                      'Available',
                      style: TextStyle(color: Colors.black38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: _isSending
                ? null
                : () => _sendProposal(user['id'], user['username']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isTopVIP
                      ? [Colors.amber, Colors.orange]
                      : [Colors.pinkAccent, Colors.pink],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: (isTopVIP ? Colors.amber : Colors.pinkAccent)
                        .withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Send',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
