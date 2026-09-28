import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CpCoupleAvatarPair extends StatelessWidget {
  const CpCoupleAvatarPair({
    super.key,
    required this.avatar1,
    required this.avatar2,
    this.size = 40,
    this.overlap = 12,
  });

  final String? avatar1;
  final String? avatar2;
  final double size;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    final width = size * 2 - overlap;
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          Positioned(left: 0, child: _avatar(avatar1)),
          Positioned(left: size - overlap, child: _avatar(avatar2)),
        ],
      ),
    );
  }

  Widget _avatar(String? url) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4),
        ],
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.grey[800]),
                errorWidget: (_, _, _) => Container(
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              )
            : Container(
                color: Colors.grey[800],
                child: const Icon(Icons.person, color: Colors.white, size: 16),
              ),
      ),
    );
  }
}
