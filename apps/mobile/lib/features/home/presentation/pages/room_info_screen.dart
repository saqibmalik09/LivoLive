import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/room_info_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/services/upload_service.dart';
import 'package:sk_live/features/home/presentation/pages/gift_center_screen.dart';
import 'package:sk_live/features/home/presentation/pages/room_decoration_screen.dart';
import 'package:sk_live/features/home/presentation/pages/room_members_screen.dart';
import 'package:sk_live/features/home/presentation/pages/room_membership_tag_screen.dart';
import 'package:sk_live/features/home/presentation/pages/room_kick_records_screen.dart';
import 'package:sk_live/core/models/room_category.dart';
import 'package:sk_live/features/home/presentation/widgets/room_category_picker_sheet.dart';
import 'package:sk_live/core/util/room_public_id.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class RoomInfoScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const RoomInfoScreen({super.key, this.roomId});

  @override
  ConsumerState<RoomInfoScreen> createState() => _RoomInfoScreenState();
}

class _RoomInfoScreenState extends ConsumerState<RoomInfoScreen> {
  Future<void> _updateField(String field, dynamic value, String roomId) async {
    final success = await ref
        .read(roomInfoProvider(widget.roomId).notifier)
        .updateRoom(roomId, {field: value});

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${field.replaceAll('_', ' ')} updated!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      roomInfoProvider(widget.roomId),
      (previous, next) {
        if (next is AsyncError) {
          if (shouldHideErrorFromUsers(next.error)) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.common_pullToRefresh),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    final roomAsync = ref.watch(roomInfoProvider(widget.roomId));
    final userProfile = ref.watch(userProfileProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.l10n.room_infoTitle,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: roomAsync.when(
        data: (room) {
          if (room == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(context.l10n.room_noRoomForAccount),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (userProfile != null) {
                        final created = await ref
                            .read(roomInfoProvider(widget.roomId).notifier)
                            .createRoom({
                              'host_id': userProfile['id'],
                              'title': '${userProfile['username']}\'s Room',
                            });
                        if (!context.mounted) return;
                        if (!created) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.room_alreadyHaveRoom),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(context.l10n.room_createMyRoom),
                  ),
                ],
              ),
            );
          }

          final String roomId = room['id'];
          final String roomTitle = room['title'] ?? context.l10n.common_room;
          final String roomTopicSlug = RoomCategory.dbValueFor(
            room['room_topic'] as String?,
          );
          final String roomTopicLabel = RoomCategory.labelFor(roomTopicSlug);
          final String? roomCover = room['image_url'];
          final String? roomAnnouncement = room['announcement'];
          final host = room['host'];
          final String countryCode =
              (room['country_code'] ??
                      (host is Map ? host['country_code'] : null) ??
                      '')
                  .toString();
          final stats = room['room_stats'];
          final int currentLevel = (stats is Map
              ? (stats['current_level'] ?? 1)
              : 1);
          final bool isPrivate = room['is_private'] ?? false;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildSection([
                  _buildInfoItem(
                    context.l10n.room_cover,
                    trailing: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF005696),
                        borderRadius: BorderRadius.circular(8),
                        image: roomCover != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(roomCover),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: roomCover == null
                          ? Text(
                              roomTitle.isNotEmpty
                                  ? roomTitle[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    onTap: () async {
                      final url = await UploadService.instance.pickRoomCover(
                        context,
                      );
                      if (url != null) {
                        await _updateField('image_url', url, roomId);
                      }
                    },
                  ),
                  _buildInfoItem(
                    'Room ID',
                    value: roomPublicId(Map<String, dynamic>.from(room)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          roomPublicId(Map<String, dynamic>.from(room)),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.copy,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: roomPublicId(
                                  Map<String, dynamic>.from(room),
                                ),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.room_idCopied),
                              ),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    showChevron: false,
                  ),
                  _buildInfoItem(
                    context.l10n.room_name,
                    value: roomTitle,
                    onTap: () => _showEditDialog(
                      context.l10n.room_name,
                      'title',
                      roomTitle,
                      roomId,
                    ),
                  ),
                  _buildInfoItem(
                    context.l10n.room_topic,
                    value: roomTopicLabel,
                    onTap: () => _showRoomCategoryPicker(roomTopicSlug, roomId),
                  ),
                  _buildInfoItem(
                    context.l10n.room_levelLabel,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hexagon, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Lv$currentLevel',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    showChevron: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const GiftCenterScreen(initialPage: 2),
                        ),
                      );
                    },
                  ),
                  _buildInfoItem(
                    context.l10n.room_country,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          countryCode,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    showChevron: false,
                  ),
                ]),

                const SizedBox(height: 12),
                _buildSection([
                  _buildInfoItem(
                    context.l10n.room_announcement,
                    value: roomAnnouncement ?? context.l10n.room_clickToSet,
                    onTap: () => _showEditDialog(
                      context.l10n.room_announcement,
                      'announcement',
                      roomAnnouncement ?? '',
                      roomId,
                    ),
                  ),
                  _buildInfoItem(
                    context.l10n.room_decoration,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoomDecorationScreen(
                            roomId: roomId,
                            currentDecorationId: room['decoration_id'],
                            currentBackgroundUrl: room['background_url'],
                          ),
                        ),
                      );
                    },
                  ),
                  _buildInfoItem(
                    context.l10n.room_lockPasswordTitle,
                    subtitle: roomHasLockPassword(room)
                        ? context.l10n.room_passwordSetTap
                        : context.l10n.room_setPasswordHint,
                    showChevron: true,
                    onTap: () => _showPasswordDialog(
                      room['room_password']?.toString() ?? '',
                      roomId,
                    ),
                  ),
                  _buildSwitchItem(
                    context.l10n.room_privateRoom,
                    isPrivate,
                    (val) => _updateField('is_private', val, roomId),
                  ),
                  _buildSwitchItem(
                    context.l10n.room_showSpendingIcons,
                    room['show_spending'] != false,
                    (val) => _updateField('show_spending', val, roomId),
                  ),
                ]),

                const SizedBox(height: 12),
                _buildSection([
                  _buildInfoItem(
                    context.l10n.room_membersList,
                    value: context.l10n.room_viewAll,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RoomMembersScreen(roomId: roomId),
                        ),
                      );
                    },
                  ),
                  _buildInfoItem(
                    context.l10n.room_membershipTag,
                    value:
                        room['membership_tag_name'] ??
                        context.l10n.room_clickToSet,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RoomMembershipTagScreen(room: room),
                        ),
                      );
                    },
                  ),
                  _buildInfoItem(
                    context.l10n.room_kickRecordsTitle,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RoomKickRecordsScreen(roomId: roomId),
                        ),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => asyncErrorWidget(err),
      ),
    );
  }

  void _showPasswordDialog(String currentPassword, String roomId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _RoomInfoPasswordDialog(
        initialPassword: currentPassword,
        onSave: (newPass) async {
          final success = await ref
              .read(roomInfoProvider(widget.roomId).notifier)
              .updateRoom(roomId, {
                'room_password': newPass.isEmpty ? null : newPass,
                'is_locked': newPass.isNotEmpty,
              });
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  newPass.isEmpty
                      ? context.l10n.room_lockPasswordRemoved
                      : context.l10n.room_lockPasswordSaved,
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _showRoomCategoryPicker(String currentSlug, String roomId) {
    showRoomCategoryPickerSheet(
      context: context,
      currentSlug: currentSlug,
      onSelected: (slug) => _updateField('room_topic', slug, roomId),
    );
  }

  void _showEditDialog(
    String title,
    String field,
    String currentValue,
    String roomId,
  ) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.room_editTitle(title)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter $title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () {
              _updateField(field, controller.text, roomId);
              Navigator.pop(context);
            },
            child: Text(context.l10n.common_save),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE)),
          bottom: BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          return Column(
            children: [
              children[index],
              if (index < children.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Divider(height: 1, thickness: 0.5),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildInfoItem(
    String title, {
    String? value,
    String? subtitle,
    Widget? trailing,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.right,
            )
          : null,
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (showChevron) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ],
          ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.pinkAccent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }
}

class _RoomInfoPasswordDialog extends StatefulWidget {
  const _RoomInfoPasswordDialog({
    required this.initialPassword,
    required this.onSave,
  });

  final String initialPassword;
  final Future<void> Function(String newPass) onSave;

  @override
  State<_RoomInfoPasswordDialog> createState() =>
      _RoomInfoPasswordDialogState();
}

class _RoomInfoPasswordDialogState extends State<_RoomInfoPasswordDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPassword);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPass = _controller.text.trim();
    if (newPass.isNotEmpty && newPass.length < 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.room_passwordDigits)));
      return;
    }
    Navigator.pop(context);
    await widget.onSave(newPass);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.room_lockPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.room_lockPasswordHelp,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: context.l10n.room_enterPassword,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_cancel),
        ),
        TextButton(onPressed: _save, child: Text(context.l10n.common_save)),
      ],
    );
  }
}
