import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/widgets/copy_on_long_press.dart';
import 'package:sk_live/core/widgets/stretch_chat_bubble.dart';
import 'package:sk_live/core/widgets/user_badge_chip.dart';

class DynamicChatBubble extends ConsumerWidget {
  final String? userId;
  final String? iconUrl;
  final String username;
  final String content;
  final Color? bgColor;
  final Color? borderColor;
  final Color? nameColor;
  final double iconSize;
  final String? senderAvatar;

  final double maxWidthFactor;

  final String? frameUrl;

  final String? frameSvgaUrl;

  final String? imageUrl;

  final String? localImagePath;
  final bool isUploadingImage;
  final VoidCallback? onImageTap;

  final List<Map<String, dynamic>>? mentions;

  final String? highlightUserId;

  const DynamicChatBubble({
    super.key,
    this.userId,
    this.iconUrl,
    required this.username,
    required this.content,
    this.bgColor,
    this.borderColor,
    this.nameColor,
    this.iconSize = 22,
    this.senderAvatar,
    this.maxWidthFactor = 0.72,
    this.frameUrl,
    this.frameSvgaUrl,
    this.imageUrl,
    this.localImagePath,
    this.isUploadingImage = false,
    this.onImageTap,
    this.mentions,
    this.highlightUserId,
  });

  bool get _hasPhoto =>
      (imageUrl?.isNotEmpty ?? false) || (localImagePath?.isNotEmpty ?? false);

  String? get _copyText {
    final parts = <String>[];
    if (content.trim().isNotEmpty) parts.add(content.trim());
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      parts.add(imageUrl!.trim());
    }
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  static const _mentionColor = Color(0xFFFFD54F);
  static const _selfMentionColor = Color(0xFFFFAB40);

  Widget _buildContentText() {
    final names = <String>{};
    final selfNames = <String>{};
    for (final m in mentions ?? const []) {
      final name = (m['username'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      names.add(name);
      if (highlightUserId != null &&
          m['user_id']?.toString() == highlightUserId) {
        selfNames.add(name.toLowerCase());
      }
    }

    if (names.isEmpty || !content.contains('@')) {
      return Text(
        content,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      );
    }

    final pattern = RegExp(
      '@(?:${names.map(RegExp.escape).join('|')})(?![\\w.\\-])',
      caseSensitive: false,
    );
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in pattern.allMatches(content)) {
      if (match.start > start) {
        spans.add(TextSpan(text: content.substring(start, match.start)));
      }
      final token = match.group(0)!;
      final isSelf = selfNames.contains(token.substring(1).toLowerCase());
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            color: isSelf ? _selfMentionColor : _mentionColor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      );
      start = match.end;
    }
    if (start < content.length) {
      spans.add(TextSpan(text: content.substring(start)));
    }

    return Text.rich(
      TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        children: spans,
      ),
    );
  }

  Widget _buildPhoto() {
    const maxWidth = 180.0;
    const maxHeight = 180.0;

    Widget picture;
    if (localImagePath?.isNotEmpty ?? false) {
      picture = Image.file(
        File(localImagePath!),
        fit: BoxFit.cover,
        width: maxWidth,
      );
    } else {
      picture = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        width: maxWidth,
        placeholder: (context, url) =>
            Container(width: maxWidth, height: 120, color: Colors.white10),
        errorWidget: (context, url, error) => Container(
          width: maxWidth,
          height: 120,
          color: Colors.white10,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image, color: Colors.white38),
        ),
      );
    }

    return GestureDetector(
      onTap: isUploadingImage ? null : onImageTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: picture,
            ),
            if (isUploadingImage)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black45,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              )
            else if (onImageTap != null)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = userId != null
        ? ref.watch(userBadgesProvider(userId!))
        : const AsyncValue<List<UserBadgeModel>>.data([]);
    final maxW = MediaQuery.sizeOf(context).width * maxWidthFactor;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (senderAvatar != null && senderAvatar!.isNotEmpty) ...[
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white10,
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: senderAvatar!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Icon(
                      Icons.person,
                      size: 10,
                      color: Colors.white24,
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.person,
                      size: 10,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
            ],
            Flexible(
              child: Text(
                '$username: ',
                style: TextStyle(
                  color: nameColor ?? borderColor ?? Colors.purpleAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (userId != null)
          badgesAsync.maybeWhen(
            data: (badges) {
              final shown = badges
                  .where(
                    (b) =>
                        b.imageUrl.trim().isNotEmpty &&
                        (b.type == 'title' ||
                            b.type == 'medal' ||
                            b.type == 'vip' ||
                            b.type == 'wealth' ||
                            b.type == 'charm'),
                  )
                  .toList();
              if (shown.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: shown.map((b) {
                    final h = b.type == 'title'
                        ? 12.0
                        : (b.type == 'medal'
                              ? 14.0
                              : (b.type == 'vip' ? 10.0 : 12.0));
                    return UserBadgeChip(badge: b, height: h);
                  }).toList(),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: 2),
          _buildContentText(),
        ],
        if (_hasPhoto) ...[const SizedBox(height: 6), _buildPhoto()],
      ],
    );

    final netFrame = frameUrl?.trim();
    final useStretch = netFrame != null && netFrame.isNotEmpty;

    final bubble = useStretch
        ? Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            child: StretchChatBubble(
              networkUrl: netFrame,
              svgaUrl: frameSvgaUrl,
              maxWidth: maxW,
              child: body,
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(top: 6, left: 10),
            decoration: BoxDecoration(
              color: bgColor ?? const Color(0xFF4A148C).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (borderColor ?? Colors.purpleAccent).withValues(
                  alpha: 0.3,
                ),
                width: 1,
              ),
            ),
            child: body,
          );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: CopyOnLongPress(
          text: _copyText,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              bubble,
              if (!useStretch && iconUrl != null && iconUrl!.isNotEmpty)
                Positioned(
                  top: 0,
                  left: 0,
                  child: CachedNetworkImage(
                    imageUrl: Uri.decodeFull(iconUrl!.trim()),
                    height: iconSize,
                    width: iconSize,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
