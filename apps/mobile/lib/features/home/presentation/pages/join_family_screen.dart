import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/family_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';

class JoinFamilyScreen extends ConsumerStatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> {
  String _searchQuery = '';
  final Set<String> _applyingIds = {};

  Widget _buildAvatar(String? url, double size) {
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: Icon(Icons.person, color: Colors.white, size: size * 0.6),
      );
    }
    final isSvg = url.toLowerCase().contains('.svg');
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: isSvg
            ? SvgPicture.network(url, fit: BoxFit.cover)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[800]),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
      ),
    );
  }

  Future<void> _applyToFamily(String familyId) async {
    setState(() => _applyingIds.add(familyId));
    try {
      await FamilyActions.requestJoin(familyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application sent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _applyingIds.remove(familyId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final familiesAsync = ref.watch(allFamiliesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Join Family', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search families...',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(
                    Iconsax.search_normal,
                    color: Colors.white38,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          Expanded(
            child: familiesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
              error: (e, st) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (families) {
                final filteredFamilies = families
                    .where(
                      (f) =>
                          f.name.toLowerCase().contains(_searchQuery) ||
                          (f.tag?.toLowerCase().contains(_searchQuery) ??
                              false),
                    )
                    .toList();

                if (filteredFamilies.isEmpty) {
                  return const Center(
                    child: Text(
                      'No families found',
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredFamilies.length,
                  itemBuilder: (context, index) {
                    final family = filteredFamilies[index];
                    return _buildFamilyTile(family);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyTile(FamilyModel family) {
    final isApplying = _applyingIds.contains(family.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          _buildAvatar(family.avatarUrl, 60),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (family.tag != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Consumer(
                          builder: (context, ref, child) {
                            final badgeAsync = ref.watch(
                              familyBadgeProvider(family.level),
                            );
                            return badgeAsync.when(
                              data: (url) {
                                if (url == null)
                                  return const Icon(
                                    Icons.workspace_premium,
                                    color: Colors.white,
                                    size: 10,
                                  );
                                return CachedNetworkImage(
                                  imageUrl: url,
                                  height: 12,
                                  placeholder: (context, url) =>
                                      const SizedBox(width: 12),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.workspace_premium,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                );
                              },
                              loading: () => const SizedBox(width: 12),
                              error: (_, _) => const Icon(
                                Icons.workspace_premium,
                                color: Colors.white,
                                size: 10,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        Text(
                          family.tag!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Leader: ${family.leaderName ?? 'Unknown'}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: isApplying ? null : () => _applyToFamily(family.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00A36C), Color(0xFF006B3C)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A36C).withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: isApplying
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Apply',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
