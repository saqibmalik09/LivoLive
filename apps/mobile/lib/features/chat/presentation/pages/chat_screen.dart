import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sk_live/core/providers/pending_messages_provider.dart';
import 'package:sk_live/core/util/string_truncate.dart';
import 'package:uuid/uuid.dart';
import 'package:sk_live/core/services/notification_service.dart';
import 'package:sk_live/features/chat/presentation/widgets/chat_gift_sheet.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/core/widgets/user_profile_mini_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/room_invite_helper.dart';
import 'package:sk_live/core/widgets/follow_relationship_button.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/providers/inventory_provider.dart' hide supabase;
import 'package:sk_live/core/widgets/stretch_chat_bubble.dart';
import 'package:sk_live/core/widgets/copy_on_long_press.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String targetUserId;
  final String targetUsername;
  final String? targetAvatar;
  final bool embeddedInSheet;
  final VoidCallback? onBack;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.targetUserId,
    required this.targetUsername,
    this.targetAvatar,
    this.embeddedInSheet = false,
    this.onBack,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    NotificationService.activeConversationId = widget.conversationId;
    _messageFocus.addListener(_onMessageFocusChanged);
  }

  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  List<double> _amplitudes = [];
  Map<String, dynamic>? _replyTo;

  void _onMessageFocusChanged() {
    if (_messageFocus.hasFocus && _scrollController.hasClients) {
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _setReplyTo(Map<String, dynamic> message) {
    setState(() => _replyTo = Map<String, dynamic>.from(message));
    HapticFeedback.lightImpact();
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      _messageFocus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _clearReply() {
    if (_replyTo == null) return;
    setState(() => _replyTo = null);
  }

  Map<String, dynamic> _replyMetadataPayload() {
    final reply = _replyTo;
    if (reply == null) return {};
    final myId = supabase.auth.currentUser?.id;
    final senderId = reply['sender_id']?.toString();
    final isMine = senderId != null && senderId == myId;
    final preview = _replyPreviewText(reply);
    return {
      'reply_to': {
        'id': reply['id']?.toString(),
        'sender_id': senderId,
        'sender_name': isMine ? 'You' : widget.targetUsername,
        'message_type': reply['message_type']?.toString() ?? 'text',
        'content': preview,
      },
    };
  }

  static String _replyPreviewText(Map<String, dynamic> msg) {
    final type = msg['message_type']?.toString() ?? 'text';
    switch (type) {
      case 'image':
        return '📷 Photo';
      case 'voice':
        return '🎤 Voice message';
      case 'gift':
        return '🎁 Gift';
      default:
        final content = (msg['content'] ?? '').toString().trim();
        if (content.isEmpty) return 'Message';
        return truncateGraphemes(content, 80);
    }
  }

  @override
  void dispose() {
    if (NotificationService.activeConversationId == widget.conversationId) {
      NotificationService.activeConversationId = null;
    }

    _messageFocus.removeListener(_onMessageFocusChanged);
    _amplitudeSubscription?.cancel();
    _recordTimer?.cancel();
    _messageFocus.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _showFullScreenGift(String svgaUrl) {
    debugPrint('[CHAT_DEBUG]: Showing full screen gift: $svgaUrl');
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return IgnorePointer(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: RaveSVGAPlayer(
                    resUrl: svgaUrl,
                    repeat: false,
                    fit: BoxFit.cover,
                    playbackSpeed: 1.5,
                    onFinished: () {
                      if (entry.mounted) entry.remove();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context).insert(entry);

    Future.delayed(const Duration(seconds: 15), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  static Map<String, dynamic> _metadataOf(dynamic meta) {
    if (meta is Map) return Map<String, dynamic>.from(meta);
    if (meta is String && meta.isNotEmpty) {
      try {
        final decoded = jsonDecode(meta);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  static bool _metaFlag(Map<String, dynamic> meta, String key) {
    final v = meta[key];
    return v == true || v == 'true' || v == 1 || v == '1';
  }

  static String? _tempIdOf(Map<String, dynamic> msg) {
    return _metadataOf(msg['metadata'])['temp_id']?.toString();
  }

  bool _remoteCoversPending(
    List<Map<String, dynamic>> remote,
    Map<String, dynamic> pending,
  ) {
    final tid = pending['id']?.toString();
    if (tid != null) {
      for (final m in remote) {
        if (_tempIdOf(m) == tid) return true;
      }
    }
    final myId = pending['sender_id']?.toString();
    final content = pending['content']?.toString();
    final type = pending['message_type']?.toString();
    if (myId == null) return false;
    for (final m in remote) {
      if (m['sender_id']?.toString() != myId) continue;
      if (type != null && m['message_type']?.toString() != type) continue;
      if (type == 'text' && content != null && content.isNotEmpty) {
        if (m['content']?.toString() == content) return true;
      } else if (type == 'image' || type == 'voice' || type == 'gift') {
        final created = DateTime.tryParse(m['created_at']?.toString() ?? '');
        if (created != null &&
            DateTime.now().difference(created).inSeconds < 45) {
          return true;
        }
      }
    }
    return false;
  }

  void _reconcilePendingWithRemote(List<Map<String, dynamic>> remote) {
    final pending = ref.read(pendingMessagesProvider(widget.conversationId));
    if (pending.isEmpty) return;
    final notifier = ref.read(
      pendingMessagesProvider(widget.conversationId).notifier,
    );
    for (final p in pending) {
      final id = p['id']?.toString();
      if (id == null) continue;
      if (_remoteCoversPending(remote, p)) {
        notifier.removeMessage(id);
      }
    }
  }

  void _afterSendSuccess(String tempId) {
    if (!mounted) return;
    ref
        .read(pendingMessagesProvider(widget.conversationId).notifier)
        .updateMessage(tempId, {'status': 'sent'});
  }

  Future<Map<String, dynamic>> _myBubbleMetadata() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return const {};
    try {
      final asset = await ref.read(equippedBubbleProvider(myId).future);
      if (asset == null) return const {};
      final url = asset.imageUrl?.trim() ?? '';
      if (url.isEmpty) return const {};
      if (!isNineSliceChatBubble(name: asset.name, imageUrl: url)) {
        return const {};
      }
      final svga = asset.svgaUrl?.trim() ?? '';
      return {
        'bubble_url': url,
        if (svga.isNotEmpty) 'bubble_svga': svga,
        if (asset.name.trim().isNotEmpty) 'bubble_name': asset.name.trim(),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final tempId = const Uuid().v4();
    final myId = supabase.auth.currentUser?.id;
    final metadata = <String, dynamic>{
      'temp_id': tempId,
      ..._replyMetadataPayload(),
      ...await _myBubbleMetadata(),
    };

    ref
        .read(pendingMessagesProvider(widget.conversationId).notifier)
        .addMessage({
          'id': tempId,
          'conversation_id': widget.conversationId,
          'sender_id': myId,
          'content': text,
          'message_type': 'text',
          'status': 'sending',
          'created_at': DateTime.now().toIso8601String(),
          'metadata': metadata,
        });

    _messageController.clear();
    _clearReply();
    _scrollToBottom();

    try {
      await ChatService.sendMessage(
        conversationId: widget.conversationId,
        type: 'text',
        content: text,
        metadata: metadata,
      );
      debugPrint('[CHAT_DEBUG]: Message successfully inserted into DB');
      _afterSendSuccess(tempId);
    } catch (e) {
      debugPrint('[CHAT_DEBUG_ERROR]: Failed to send text: $e');
      if (mounted) {
        ref
            .read(pendingMessagesProvider(widget.conversationId).notifier)
            .removeMessage(tempId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image == null) return;

    final tempId = const Uuid().v4();
    final myId = supabase.auth.currentUser?.id;
    final metadata = <String, dynamic>{
      'temp_id': tempId,
      ..._replyMetadataPayload(),
    };

    ref
        .read(pendingMessagesProvider(widget.conversationId).notifier)
        .addMessage({
          'id': tempId,
          'conversation_id': widget.conversationId,
          'sender_id': myId,
          'message_type': 'image',
          'status': 'sending',
          'media_url': image.path,
          'created_at': DateTime.now().toIso8601String(),
          'metadata': metadata,
        });
    _clearReply();

    try {
      final file = File(image.path);
      final url = await ChatService.uploadMedia(file, 'chats/images');
      if (url != null) {
        await ChatService.sendMessage(
          conversationId: widget.conversationId,
          type: 'image',
          mediaUrl: url,
          metadata: metadata,
        );
        _afterSendSuccess(tempId);
      } else if (mounted) {
        ref
            .read(pendingMessagesProvider(widget.conversationId).notifier)
            .removeMessage(tempId);
      }
    } catch (e) {
      debugPrint('[CHAT_DEBUG_ERROR]: Failed to send image: $e');
      if (mounted) {
        ref
            .read(pendingMessagesProvider(widget.conversationId).notifier)
            .removeMessage(tempId);
      }
    }
  }

  bool _isUploadingVoice = false;

  Future<void> _toggleRecording({bool cancel = false}) async {
    debugPrint(
      '[CHAT_DEBUG]: toggleRecording called. cancel=$cancel, _isRecording=$_isRecording',
    );

    if (_isRecording) {
      debugPrint('[CHAT_DEBUG]: Stopping recording sequence...');

      await _amplitudeSubscription?.cancel();
      _recordTimer?.cancel();
      _amplitudeSubscription = null;
      _recordTimer = null;

      try {
        final path = await _recorder.stop();

        await Future.delayed(const Duration(milliseconds: 200));

        if (cancel) {
          setState(() {
            _isRecording = false;
            _recordSeconds = 0;
            _amplitudes = [];
            _isUploadingVoice = false;
          });
          debugPrint('[CHAT_DEBUG]: Recording cancelled.');
          return;
        }

        if (path != null) {
          final tempId = const Uuid().v4();
          final myId = supabase.auth.currentUser?.id;
          final metadata = <String, dynamic>{
            'temp_id': tempId,
            ..._replyMetadataPayload(),
          };

          ref
              .read(pendingMessagesProvider(widget.conversationId).notifier)
              .addMessage({
                'id': tempId,
                'conversation_id': widget.conversationId,
                'sender_id': myId,
                'message_type': 'voice',
                'status': 'sending',
                'media_url': path,
                'created_at': DateTime.now().toIso8601String(),
                'metadata': metadata,
              });

          setState(() {
            _isRecording = false;
            _recordSeconds = 0;
            _amplitudes = [];
            _isUploadingVoice = false;
            _replyTo = null;
          });
          _scrollToBottom();

          try {
            debugPrint('[CHAT_DEBUG]: Recording sending in bg. Path: $path');
            final file = File(path);
            final url = await ChatService.uploadMedia(file, 'chats/voice');
            if (url != null) {
              await ChatService.sendMessage(
                conversationId: widget.conversationId,
                type: 'voice',
                mediaUrl: url,
                metadata: metadata,
              );
              _afterSendSuccess(tempId);
            } else if (mounted) {
              ref
                  .read(pendingMessagesProvider(widget.conversationId).notifier)
                  .removeMessage(tempId);
            }
          } catch (e) {
            debugPrint('[CHAT_DEBUG_ERROR]: Failed to send voice: $e');
            if (mounted) {
              ref
                  .read(pendingMessagesProvider(widget.conversationId).notifier)
                  .removeMessage(tempId);
            }
          }
        }
      } catch (e) {
        debugPrint('[CHAT_NATIVE_ERROR]: Recorder stop failed: $e');
        setState(() => _isRecording = false);
      }
    } else {
      debugPrint('[CHAT_DEBUG]: Starting recording session...');
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/record_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
          _amplitudes = List.filled(15, 0.1, growable: true);
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordSeconds++);
        });

        _amplitudeSubscription = _recorder
            .onAmplitudeChanged(const Duration(milliseconds: 100))
            .listen((amp) {
              if (!mounted) return;
              setState(() {
                double value = (amp.current + 160) / 160;
                value = value.clamp(0.1, 1.0);
                if (_amplitudes.isNotEmpty) {
                  _amplitudes.removeAt(0);
                  _amplitudes.add(value);
                }
              });
            });

        HapticFeedback.heavyImpact();
      }
    }
  }

  void _showGiftPicker() {
    final replyMeta = _replyMetadataPayload();
    if (_replyTo != null) _clearReply();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ChatGiftSheet(
        conversationId: widget.conversationId,
        targetUserId: widget.targetUserId,
        targetUsername: widget.targetUsername,
        targetAvatar: widget.targetAvatar,
        replyToMetadata: replyMeta.isEmpty ? null : replyMeta,
      ),
    );
  }

  final Set<String> _playedGiftIds = {};

  @override
  Widget build(BuildContext context) {
    final conversationAsync = ref.watch(
      conversationDetailProvider(widget.conversationId),
    );

    return Scaffold(
      backgroundColor: widget.embeddedInSheet
          ? const Color(0xFF1A1A2E)
          : const Color(0xFFF8F9FE),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: widget.embeddedInSheet
            ? const Color(0xFF1A1A2E)
            : Colors.white,
        elevation: 0,
        centerTitle: false,
        leadingWidth: 40,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: widget.embeddedInSheet
                  ? Colors.white
                  : AppColors.textPrimary,
              size: 20,
            ),
            onPressed: widget.onBack ?? () => context.pop(),
          ),
        ),
        title: GestureDetector(
          onTap: () {
            UserProfileMiniSheet.show(context, widget.targetUserId);
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.embeddedInSheet
                        ? Colors.white24
                        : AppColors.primary.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryUltraLight,
                  backgroundImage: widget.targetAvatar != null
                      ? CachedNetworkImageProvider(widget.targetAvatar!)
                      : null,
                  child: widget.targetAvatar == null
                      ? const Icon(
                          Icons.person,
                          size: 16,
                          color: AppColors.primary,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.targetUsername,
                    style: TextStyle(
                      color: widget.embeddedInSheet
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _ChatUserStatusLine(
                    userId: widget.targetUserId,
                    embeddedInSheet: widget.embeddedInSheet,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          FollowRelationshipButton(
            targetUserId: widget.targetUserId,
            compact: true,
            onDarkBackground: widget.embeddedInSheet,
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              color: widget.embeddedInSheet
                  ? Colors.white
                  : AppColors.textPrimary,
              size: 24,
            ),
            onPressed: () {
              final conv = conversationAsync.value;
              _showSafetyMenu(conv);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: Image.network(
                  'https://www.transparenttextures.com/patterns/cubes.png',
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: _ChatMessagesPane(
                    conversationId: widget.conversationId,
                    scrollController: _scrollController,
                    playedGiftIds: _playedGiftIds,
                    onShowFullScreenGift: _showFullScreenGift,
                    reconcilePendingWithRemote: _reconcilePendingWithRemote,
                    peerName: widget.targetUsername,
                    onReply: _setReplyTo,
                  ),
                ),
                conversationAsync.when(
                  data: (conv) {
                    final isBlocked = conv?['status'] == 'blocked';
                    if (isBlocked) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: MediaQuery.of(context).padding.bottom + 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Iconsax.slash,
                              color: Colors.red,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.chat_conversationBlocked,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              context.l10n.chat_blockedCannotMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return _ChatInputBar(
                      embeddedInSheet: widget.embeddedInSheet,
                      messageController: _messageController,
                      messageFocus: _messageFocus,
                      isRecording: _isRecording,
                      isUploadingVoice: _isUploadingVoice,
                      recordSeconds: _recordSeconds,
                      amplitudes: _amplitudes,
                      replyTo: _replyTo,
                      replyPreview: _replyTo == null
                          ? null
                          : _replyPreviewText(_replyTo!),
                      replyLabel: _replyTo == null
                          ? null
                          : (_replyTo!['sender_id']?.toString() ==
                                    supabase.auth.currentUser?.id
                                ? 'You'
                                : widget.targetUsername),
                      onCancelReply: _clearReply,
                      onSend: _sendMessage,
                      onAttach: () {
                        _dismissKeyboard();
                        _showMediaMenu();
                      },
                      onGift: () {
                        _dismissKeyboard();
                        _showGiftPicker();
                      },
                      onToggleRecording: _toggleRecording,
                      onDismissKeyboard: _dismissKeyboard,
                      formatSeconds: _formatSeconds,
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (err, stack) => _ChatInputBar(
                    embeddedInSheet: widget.embeddedInSheet,
                    messageController: _messageController,
                    messageFocus: _messageFocus,
                    isRecording: _isRecording,
                    isUploadingVoice: _isUploadingVoice,
                    recordSeconds: _recordSeconds,
                    amplitudes: _amplitudes,
                    replyTo: _replyTo,
                    replyPreview: _replyTo == null
                        ? null
                        : _replyPreviewText(_replyTo!),
                    replyLabel: _replyTo == null
                        ? null
                        : (_replyTo!['sender_id']?.toString() ==
                                  supabase.auth.currentUser?.id
                              ? 'You'
                              : widget.targetUsername),
                    onCancelReply: _clearReply,
                    onSend: _sendMessage,
                    onAttach: () {
                      _dismissKeyboard();
                      _showMediaMenu();
                    },
                    onGift: () {
                      _dismissKeyboard();
                      _showGiftPicker();
                    },
                    onToggleRecording: _toggleRecording,
                    onDismissKeyboard: _dismissKeyboard,
                    formatSeconds: _formatSeconds,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _showMediaMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMediaOption(
                    Iconsax.gallery,
                    'Album',
                    const Color(0xFF4A90E2),
                    () => _pickImage(ImageSource.gallery),
                  ),
                  _buildMediaOption(
                    Iconsax.camera,
                    'Camera',
                    const Color(0xFF50E3C2),
                    () => _pickImage(ImageSource.camera),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showSafetyMenu(Map<String, dynamic>? conv) {
    final isBlocked = conv?['status'] == 'blocked';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 25),
              _buildSafetyOption(
                Iconsax.flag,
                context.l10n.chat_reportUser,
                'Tell us if something is wrong',
                Colors.orange,
                () => _showReportDialog(),
              ),
              const Divider(height: 1, indent: 70),
              _buildSafetyOption(
                isBlocked ? Iconsax.unlock : Iconsax.slash,
                isBlocked ? 'Unblock User' : 'Block User',
                isBlocked
                    ? 'Allow messages from this user'
                    : 'Stop receiving messages from this user',
                Colors.red,
                () {
                  Navigator.pop(context);
                  _handleBlockUnblock(isBlocked);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyOption(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      onTap: onTap,
    );
  }

  void _showReportDialog() {
    Navigator.pop(context);
    final reasons = [
      'Spam',
      'Harassment',
      'Abusive Language',
      'Inappropriate Content',
      'Fake Profile',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.l10n.chat_reportUser,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (reason) => ListTile(
                  title: Text(reason),
                  onTap: () async {
                    Navigator.pop(context);
                    await ChatService.reportUser(
                      targetId: widget.targetUserId,
                      reason: reason,
                      conversationId: widget.conversationId,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Report submitted successfully. Thank you for your feedback.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _handleBlockUnblock(bool isCurrentlyBlocked) async {
    try {
      if (isCurrentlyBlocked) {
        await ChatService.unblockConversation(widget.conversationId);
      } else {
        await ChatService.blockConversation(widget.conversationId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyBlocked ? 'User unblocked' : 'User blocked',
            ),
            backgroundColor: isCurrentlyBlocked
                ? Colors.green
                : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.embeddedInSheet,
    required this.messageController,
    required this.messageFocus,
    required this.isRecording,
    required this.isUploadingVoice,
    required this.recordSeconds,
    required this.amplitudes,
    required this.onSend,
    required this.onAttach,
    required this.onGift,
    required this.onToggleRecording,
    required this.onDismissKeyboard,
    required this.formatSeconds,
    this.replyTo,
    this.replyPreview,
    this.replyLabel,
    this.onCancelReply,
  });

  final bool embeddedInSheet;
  final TextEditingController messageController;
  final FocusNode messageFocus;
  final bool isRecording;
  final bool isUploadingVoice;
  final int recordSeconds;
  final List<double> amplitudes;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onGift;
  final Future<void> Function({bool cancel}) onToggleRecording;
  final VoidCallback onDismissKeyboard;
  final String Function(int seconds) formatSeconds;
  final Map<String, dynamic>? replyTo;
  final String? replyPreview;
  final String? replyLabel;
  final VoidCallback? onCancelReply;

  static Widget _circle(
    IconData icon,
    VoidCallback onTap, {
    Color? bgColor,
    Color? iconColor,
    bool isTransparent = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: isTransparent
              ? Colors.transparent
              : (bgColor ?? const Color(0xFFF2F3F7)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor ?? AppColors.textSecondary,
          size: 22,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottomPad = embeddedInSheet
        ? 10.0
        : (viewInsets > 0 ? 8.0 : safeBottom + 8);

    final isDark = embeddedInSheet;
    final barBg = isDark ? const Color(0xFF252540) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF1A1A2E) : barBg;
    final replyBg = isDark ? const Color(0xFF1F1F35) : const Color(0xFFF5F6F8);
    final replyBorder = isDark ? Colors.white12 : const Color(0xFFE8E8E8);

    return RepaintBoundary(
      child: Material(
        color: barBg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyTo != null && !isRecording)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(
                  color: replyBg,
                  border: Border(
                    top: BorderSide(color: replyBorder),
                    left: const BorderSide(color: AppColors.primary, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.reply_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to ${replyLabel ?? 'message'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            replyPreview ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onCancelReply,
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: isDark ? Colors.white38 : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: EdgeInsets.fromLTRB(10, 8, 10, bottomPad),
              decoration: BoxDecoration(
                color: barBg,
                border: Border(top: BorderSide(color: replyBorder, width: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isRecording) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _circle(
                        Iconsax.add,
                        onAttach,
                        bgColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : null,
                        iconColor: isDark ? Colors.white70 : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: isRecording
                        ? _recordingOverlay(isDark: isDark)
                        : _ChatComposerField(
                            controller: messageController,
                            focusNode: messageFocus,
                            fieldBg: fieldBg,
                            isDark: isDark,
                            onTapOutside: onDismissKeyboard,
                          ),
                  ),
                  if (!isRecording) ...[
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _circle(
                        Iconsax.gift,
                        onGift,
                        bgColor: AppColors.primaryUltraLight,
                        iconColor: AppColors.primary,
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  if (!isRecording)
                    ListenableBuilder(
                      listenable: messageController,
                      builder: (context, _) {
                        final hasText = messageController.text
                            .trim()
                            .isNotEmpty;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: hasText
                              ? _circle(
                                  Icons.send_rounded,
                                  onSend,
                                  bgColor: AppColors.primary,
                                  iconColor: Colors.white,
                                )
                              : GestureDetector(
                                  onTap: () {
                                    onDismissKeyboard();
                                    onToggleRecording();
                                  },
                                  child: Container(
                                    height: 44,
                                    width: 44,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryUltraLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.mic_none_rounded,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                ),
                        );
                      },
                    )
                  else ...[
                    _circle(
                      Iconsax.trash,
                      isUploadingVoice
                          ? () {}
                          : () {
                              onToggleRecording(cancel: true);
                            },
                      bgColor: Colors.red.withValues(alpha: 0.1),
                      iconColor: isUploadingVoice ? Colors.grey : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    isUploadingVoice
                        ? Container(
                            height: 44,
                            width: 44,
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : _circle(
                            Icons.send_rounded,
                            () => onToggleRecording(cancel: false),
                            bgColor: AppColors.primary,
                            iconColor: Colors.white,
                          ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordingOverlay({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.circle,
            color: Colors.red,
            size: 8,
          ).animate(onPlay: (c) => c.repeat()).fadeOut(duration: 500.ms),
          const SizedBox(width: 8),
          Text(
            formatSeconds(recordSeconds),
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: amplitudes
                  .map(
                    (amp) => AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 3,
                      height: (10 + (25 * amp)).toDouble(),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Recording...',
            style: TextStyle(
              color: isDark ? Colors.white54 : AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatUserStatusLine extends ConsumerWidget {
  const _ChatUserStatusLine({
    required this.userId,
    required this.embeddedInSheet,
  });

  final String userId;
  final bool embeddedInSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userStatusProvider(userId));
    final muted = embeddedInSheet ? Colors.white54 : AppColors.textSecondary;

    return async.when(
      data: (user) {
        if (user == null) {
          return Text(
            context.l10n.chat_offline,
            style: TextStyle(fontSize: 11, color: muted),
          );
        }
        final updatedAtStr = user['updated_at']?.toString();
        if (updatedAtStr == null) {
          return Text(
            context.l10n.chat_offline,
            style: TextStyle(fontSize: 11, color: muted),
          );
        }
        final updatedAt = DateTime.parse(updatedAtStr);
        final diff = DateTime.now().difference(updatedAt);
        final isOnline = user['is_online'] == true || diff.inMinutes < 2;
        return Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFF4CAF50) : AppColors.textHint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isOnline
                  ? 'Active now'
                  : 'Last seen ${timeago.format(updatedAt, locale: 'en_short')}',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        );
      },
      loading: () => Text('...', style: TextStyle(fontSize: 11, color: muted)),
      error: (_, __) => Text(
        context.l10n.chat_offline,
        style: TextStyle(fontSize: 11, color: muted),
      ),
    );
  }
}

class _ChatMessagesPane extends ConsumerStatefulWidget {
  const _ChatMessagesPane({
    required this.conversationId,
    required this.scrollController,
    required this.playedGiftIds,
    required this.onShowFullScreenGift,
    required this.reconcilePendingWithRemote,
    required this.peerName,
    required this.onReply,
  });

  final String conversationId;
  final ScrollController scrollController;
  final Set<String> playedGiftIds;
  final void Function(String svgaUrl) onShowFullScreenGift;
  final void Function(List<Map<String, dynamic>> remote)
  reconcilePendingWithRemote;
  final String peerName;
  final ValueChanged<Map<String, dynamic>> onReply;

  @override
  ConsumerState<_ChatMessagesPane> createState() => _ChatMessagesPaneState();
}

class _ChatMessagesPaneState extends ConsumerState<_ChatMessagesPane> {
  static String? _tempIdOf(Map<String, dynamic> msg) {
    final meta = msg['metadata'];
    if (meta is Map) return meta['temp_id']?.toString();
    return null;
  }

  bool _remoteCoversPending(
    List<Map<String, dynamic>> remote,
    Map<String, dynamic> pending,
  ) {
    final tid = pending['id']?.toString();
    if (tid == null) return false;
    for (final m in remote) {
      if (_tempIdOf(m) == tid) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      chatMessagesProvider(widget.conversationId),
    );
    final pendingMessages = ref.watch(
      pendingMessagesProvider(widget.conversationId),
    );
    final deletedIds = ref.watch(
      deletedChatMessagesProvider(widget.conversationId),
    );

    ref.listen(chatMessagesProvider(widget.conversationId), (previous, next) {
      final msgs = next.value;
      if (msgs == null || msgs.isEmpty) return;

      widget.reconcilePendingWithRemote(msgs);

      final lastMessage = msgs.first;
      final myId = supabase.auth.currentUser?.id;

      if (lastMessage['sender_id'] != myId && lastMessage['is_read'] == false) {
        ChatService.markAsRead(widget.conversationId);
      }

      final bool isNew =
          previous?.value == null ||
          !previous!.value!.any((m) => m['id'] == lastMessage['id']);

      if (isNew && lastMessage['message_type'] == 'gift') {
        final metadata = lastMessage['metadata'] as Map<String, dynamic>?;
        if (metadata != null) {
          final svgaUrl = metadata['svga_url'];
          final isFullScreen = metadata['is_full_screen'] == true;
          final messageId = lastMessage['id'].toString();

          if (isFullScreen &&
              svgaUrl != null &&
              svgaUrl.toString().isNotEmpty) {
            final createdAt = DateTime.parse(lastMessage['created_at']);
            final isRecent =
                DateTime.now().difference(createdAt).inSeconds < 30;

            if (!widget.playedGiftIds.contains(messageId) && isRecent) {
              widget.playedGiftIds.add(messageId);
              widget.onShowFullScreenGift(svgaUrl.toString());
            }
          }
        }
      }
    });

    final messages =
        messagesAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final stillLoading = messagesAsync.isLoading && messages.isEmpty;

    if (stillLoading && pendingMessages.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (messagesAsync.hasError && messages.isEmpty && pendingMessages.isEmpty) {
      debugPrint(
        '[CHAT_UI_ERROR]: Error displaying messages: ${messagesAsync.error}',
      );
      return asyncErrorWidget(
        messagesAsync.error ?? 'Unknown error',
        style: const TextStyle(color: Colors.red, fontSize: 12),
      );
    }

    final coveredTempIds = <String>{};
    final remoteOnly = <Map<String, dynamic>>[];
    for (final msg in messages) {
      final id = msg['id']?.toString();
      if (id != null && deletedIds.contains(id)) continue;
      final tid = _tempIdOf(msg);
      if (tid != null) coveredTempIds.add(tid);
      remoteOnly.add(msg);
    }

    final pendingOnly = pendingMessages.where((p) {
      final id = p['id']?.toString();
      if (id != null && deletedIds.contains(id)) return false;
      if (id != null && coveredTempIds.contains(id)) return false;
      return !_remoteCoversPending(messages, p);
    }).toList();

    final allMessages = [...pendingOnly, ...remoteOnly];

    return ListView.builder(
      controller: widget.scrollController,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

      cacheExtent: 600,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: allMessages.length,
      itemBuilder: (context, index) {
        final msg = allMessages[index];
        final isMe = msg['sender_id'] == supabase.auth.currentUser?.id;
        final stableKey =
            _tempIdOf(msg) ?? msg['id']?.toString() ?? 'msg-$index';
        return RepaintBoundary(
          key: ValueKey(stableKey),
          child: _MessageBubble(
            message: msg,
            isMe: isMe,
            conversationId: widget.conversationId,
            peerName: widget.peerName,
            onReply: () => widget.onReply(msg),
          ),
        );
      },
    );
  }
}

class _ChatComposerField extends StatelessWidget {
  const _ChatComposerField({
    required this.controller,
    required this.focusNode,
    required this.fieldBg,
    required this.isDark,
    required this.onTapOutside,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color fieldBg;
  final bool isDark;
  final VoidCallback onTapOutside;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white24 : const Color(0xFFD8DCE3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: 5,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        cursorColor: AppColors.primary,
        style: TextStyle(
          fontSize: 15.5,
          height: 1.35,
          color: isDark ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        onTapOutside: (_) => onTapOutside(),
        decoration: InputDecoration(
          hintText: 'Message',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : AppColors.textHint,
            fontSize: 15.5,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}

class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.child, required this.onReply});

  final Widget child;
  final VoidCallback onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _dx = 0;
  bool _triggered = false;
  static const _threshold = 56.0;

  @override
  Widget build(BuildContext context) {
    final progress = (_dx / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        final next = (_dx + details.delta.dx).clamp(0.0, _threshold + 24);
        setState(() => _dx = next);
        if (!_triggered && _dx >= _threshold) {
          _triggered = true;
          HapticFeedback.selectionClick();
        }
      },
      onHorizontalDragEnd: (_) {
        final shouldReply = _dx >= _threshold;
        setState(() {
          _dx = 0;
          _triggered = false;
        });
        if (shouldReply) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onReply();
          });
        }
      },
      onHorizontalDragCancel: () {
        setState(() {
          _dx = 0;
          _triggered = false;
        });
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Opacity(
            opacity: progress,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.reply_rounded,
                size: 22,
                color: AppColors.primary.withValues(alpha: 0.85),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String conversationId;
  final String peerName;
  final VoidCallback onReply;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.conversationId,
    required this.peerName,
    required this.onReply,
  });

  Widget _buildStatusTicks() {
    const readColor = Color(0xFF34B7F1);
    final status = message['status']?.toString();

    if (status == 'sending') {
      return const Icon(
        Icons.access_time_rounded,
        size: 11,
        color: AppColors.textHint,
      );
    }
    if (status == 'sent') {
      return const Icon(Icons.check, size: 12, color: AppColors.textHint);
    }

    final isRead = message['is_read'] == true;
    return Icon(
      Icons.done_all,
      size: 12,
      color: isRead ? readColor : AppColors.textHint,
    );
  }

  String? _copyableText(BuildContext context) {
    final type = message['message_type']?.toString() ?? 'text';
    final content = (message['content'] ?? '').toString().trim();
    final url = (message['media_url'] ?? '').toString().trim();

    switch (type) {
      case 'image':
        if (content.isNotEmpty && url.isNotEmpty) return '$content\n$url';
        if (content.isNotEmpty) return content;
        return url.isNotEmpty ? url : null;
      case 'voice':
        return url.isNotEmpty ? url : 'Voice message';
      case 'gift':
        return content.isNotEmpty ? content : context.l10n.chat_sentAGift;
      default:
        final metadata = _ChatScreenState._metadataOf(message['metadata']);
        if (_ChatScreenState._metaFlag(metadata, 'is_room_invite')) {
          final title = metadata['room_title']?.toString() ?? 'Live Room';
          final host = metadata['host_username']?.toString() ?? '';
          return host.isEmpty ? title : '$title — $host';
        }
        return content.isNotEmpty ? content : null;
    }
  }

  Future<void> _onLongPress(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final copyText = _copyableText(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Iconsax.copy, color: AppColors.primary),
                  title: const Text(
                    'Copy',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.pop(ctx, 'copy'),
                ),
                if (isMe)
                  ListTile(
                    leading: const Icon(Iconsax.trash, color: Colors.redAccent),
                    title: const Text(
                      'Delete message',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                    subtitle: const Text('Removed for both of you'),
                    onTap: () => Navigator.pop(ctx, 'delete'),
                  ),
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted) return;

    if (action == 'copy') {
      final text = copyText?.trim() ?? '';
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nothing to copy'),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chat_copied),
            duration: const Duration(milliseconds: 900),
          ),
        );
      }
      return;
    }

    if (action != 'delete' || !isMe) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'This message will be deleted for both people in this chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final id = message['id']?.toString();
    if (id == null || id.isEmpty) return;

    try {
      if (message['status'] == 'sending') {
        ref
            .read(pendingMessagesProvider(conversationId).notifier)
            .removeMessage(id);
        return;
      }
      ref
          .read(deletedChatMessagesProvider(conversationId).notifier)
          .markDeleted(id);
      await ChatService.deleteMessage(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      ref.read(deletedChatMessagesProvider(conversationId).notifier).unmark(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shouldHideErrorFromUsers(e)
                  ? 'Could not delete message'
                  : 'Could not delete message: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String? _resolveFrameUrl(WidgetRef ref) {
    final meta = _ChatScreenState._metadataOf(message['metadata']);
    final metaUrl = meta['bubble_url']?.toString().trim();
    final metaName = meta['bubble_name']?.toString();
    if (metaUrl != null &&
        metaUrl.isNotEmpty &&
        isNineSliceChatBubble(name: metaName, imageUrl: metaUrl)) {
      return metaUrl;
    }

    final senderId = message['sender_id']?.toString() ?? '';
    if (senderId.isEmpty) return null;
    final asset = ref.watch(equippedBubbleProvider(senderId)).valueOrNull;
    if (asset == null) return null;
    final url = asset.imageUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    if (!isNineSliceChatBubble(name: asset.name, imageUrl: url)) return null;
    return url;
  }

  String? _resolveFrameSvga(WidgetRef ref) {
    final meta = _ChatScreenState._metadataOf(message['metadata']);
    final metaSvga = meta['bubble_svga']?.toString().trim();
    if (metaSvga != null && metaSvga.isNotEmpty) return metaSvga;

    final senderId = message['sender_id']?.toString() ?? '';
    if (senderId.isEmpty) return null;
    final asset = ref.watch(equippedBubbleProvider(senderId)).valueOrNull;
    final svga = asset?.svgaUrl?.trim() ?? '';
    return svga.isNotEmpty ? svga : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = message['message_type']?.toString() ?? 'text';
    final frameUrl = _resolveFrameUrl(ref);
    final frameSvga = _resolveFrameSvga(ref);
    final useFrame =
        frameUrl != null &&
        frameUrl.isNotEmpty &&
        (type == 'text' || type == 'gift');

    final bubbleBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReplyQuote(context, framed: useFrame),
        _buildMessageContent(context, framed: useFrame),
      ],
    );

    final maxW = MediaQuery.sizeOf(context).width * 0.72;

    final bubble = useFrame
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: StretchChatBubble(
              networkUrl: frameUrl,
              svgaUrl: frameSvga,
              maxWidth: maxW,
              child: bubbleBody,
            ),
          )
        : Container(
            constraints: BoxConstraints(maxWidth: maxW),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF9C4DFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isMe ? null : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
            ),
            child: bubbleBody,
          );

    return _SwipeToReply(
      onReply: onReply,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: Color(0xFFE0E0E0),
                  child: Icon(Icons.person, size: 12, color: Colors.white),
                ),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  isMe
                      ? GestureDetector(
                          onLongPress: () => _onLongPress(context, ref),
                          child: bubble,
                        )
                      : CopyOnLongPress(
                          text: _copyableText(context),
                          emptyHint: 'Nothing to copy',
                          borderRadius: BorderRadius.circular(16),
                          child: bubble,
                        ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeago.format(DateTime.parse(message['created_at'])),
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildStatusTicks(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyQuote(BuildContext context, {required bool framed}) {
    final meta = _ChatScreenState._metadataOf(message['metadata']);
    final reply = meta['reply_to'];
    if (reply is! Map) return const SizedBox.shrink();

    final name =
        reply['sender_name']?.toString() ??
        (reply['sender_id']?.toString() == supabase.auth.currentUser?.id
            ? 'You'
            : peerName);
    final content = reply['content']?.toString() ?? '';
    final barColor = framed
        ? Colors.white70
        : (isMe ? Colors.white70 : AppColors.primary);
    final bg = framed
        ? Colors.white.withValues(alpha: 0.14)
        : (isMe
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.08));
    final nameColor = framed
        ? Colors.white
        : (isMe ? Colors.white : AppColors.primary);
    final bodyColor = framed
        ? Colors.white70
        : (isMe ? Colors.white70 : AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: barColor, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: nameColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: bodyColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, {bool framed = false}) {
    final type = message['message_type'];
    final content = message['content'];
    final url = message['media_url'];
    final textColor = framed
        ? Colors.white
        : (isMe ? Colors.white : AppColors.textPrimary);

    switch (type) {
      case 'image':
        final isLocal = url?.startsWith('/') ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isLocal
                  ? Image.file(File(url!), fit: BoxFit.cover)
                  : CachedNetworkImage(
                      imageUrl: url!,
                      placeholder: (context, url) =>
                          Container(color: AppColors.background, height: 150),
                    ),
            ),
            if (content != null && content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(content, style: TextStyle(color: textColor, fontSize: 14)),
            ],
          ],
        );
      case 'gift':
        final metadata = message['metadata'] as Map<String, dynamic>?;
        final giftIcon = metadata?['gift_icon'];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (giftIcon != null)
              CachedNetworkImage(
                imageUrl: giftIcon,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              )
            else
              const Icon(Icons.card_giftcard, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                content ?? context.l10n.chat_sentAGift,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      case 'voice':
        return _VoiceMessagePlayer(url: url!, isMe: isMe);
      default:
        final metadata = _ChatScreenState._metadataOf(message['metadata']);
        if (_ChatScreenState._metaFlag(metadata, 'is_room_invite')) {
          return _RoomInviteBubble(message: message, isMe: isMe);
        }
        return Text(
          content ?? '',
          style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
        );
    }
  }
}

class _RoomInviteBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const _RoomInviteBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final metadata = message['metadata'] as Map<String, dynamic>?;
    final title = metadata?['room_title'] ?? 'Live Room';
    final host = metadata?['host_username'] ?? '';
    final imageUrl = metadata?['room_image_url'] as String?;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => RoomInviteHelper.openRoomFromInvite(context, metadata),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isMe ? 0.2 : 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null
                    ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                    : Icon(
                        Icons.mic,
                        color: isMe ? Colors.white : AppColors.primary,
                      ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isMe ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (host.isNotEmpty)
                      Text(
                        'by $host',
                        style: TextStyle(
                          color: isMe
                              ? Colors.white70
                              : AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to join room',
                      style: TextStyle(
                        color: isMe ? Colors.yellowAccent : AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_fill,
                color: isMe ? Colors.yellowAccent : AppColors.primary,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final bool isMe;

  const _VoiceMessagePlayer({required this.url, required this.isMe});

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onDurationChanged.listen((d) => setState(() => _duration = d));
    _player.onPositionChanged.listen((p) => setState(() => _position = p));
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      final isLocal = widget.url.startsWith('/');
      if (isLocal) {
        await _player.play(DeviceFileSource(widget.url));
      } else {
        await _player.play(UrlSource(widget.url));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: widget.isMe ? Colors.white : AppColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: LinearProgressIndicator(
            value: _duration.inMilliseconds > 0
                ? _position.inMilliseconds / _duration.inMilliseconds
                : 0.0,
            backgroundColor: (widget.isMe ? Colors.white : AppColors.primary)
                .withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.isMe ? Colors.white : AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_isPlaying ? _position : _duration),
          style: TextStyle(
            color: widget.isMe ? Colors.white : AppColors.textPrimary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
