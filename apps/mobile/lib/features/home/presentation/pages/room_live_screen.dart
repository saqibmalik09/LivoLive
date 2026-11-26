import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sk_live/core/widgets/dynamic_chat_bubble.dart';
import 'package:sk_live/core/widgets/stretch_chat_bubble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/voice_backend_provider.dart';
import 'package:sk_live/core/services/orbit_voice_session_service.dart';
import 'package:sk_live/core/services/app_telemetry.dart';
import 'package:sk_live/core/util/string_truncate.dart';
import 'package:sk_live/core/services/room_exit_coordinator.dart';
import 'package:sk_live/core/services/room_switch_coordinator.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/features/home/presentation/widgets/room_gift_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/room_gift_combo_button.dart';
import 'package:sk_live/features/home/presentation/widgets/gift_flight_manager.dart';
import 'package:sk_live/features/home/presentation/widgets/room_details_sheet.dart';
import 'package:sk_live/features/home/presentation/pages/room_decoration_screen.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:sk_live/features/wallet/presentation/pages/wallet_screen.dart';
import 'package:sk_live/core/providers/recent_rooms_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/providers/seat_wear_cache.dart';
import 'package:sk_live/core/providers/inventory_provider.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/providers/wallet_coins_provider.dart';
import 'package:sk_live/core/providers/home_provider.dart';
import 'package:sk_live/core/providers/staff_provider.dart';
import 'package:sk_live/features/home/services/room_chat_image_service.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/core/widgets/room_background_media.dart';
import 'package:sk_live/core/services/background_service.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/services/room_media_keep_alive.dart';
import 'package:sk_live/core/services/room_minimized_keepalive.dart';
import 'package:sk_live/core/services/room_floating_bubble_service.dart';
import 'package:sk_live/core/util/room_public_id.dart';
import 'package:sk_live/core/util/tulasi_game.dart';
import 'package:sk_live/core/util/baishun_game.dart';
import 'package:sk_live/core/util/wave_game.dart';
import 'package:sk_live/features/games/presentation/pages/h5_game_webview_page.dart';
import 'package:sk_live/core/providers/game_overlay_provider.dart';
import 'package:sk_live/core/util/game_audience_filter.dart';
import 'package:sk_live/features/home/presentation/widgets/room_games_sheet.dart';
import 'package:sk_live/core/services/room_voice_session_service.dart';
import 'package:sk_live/core/router/room_route_observer.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/features/home/presentation/pages/room_info_screen.dart';
import 'package:sk_live/core/widgets/user_profile_mini_sheet.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/features/chat/presentation/pages/chat_screen.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/services/task_tracker_service.dart';
import 'package:sk_live/features/home/presentation/widgets/room_share_to_chat_sheet.dart';
import 'package:sk_live/core/providers/room_invitation_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/room_seat_invite_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/room_seat_invite_dialog.dart';
import 'package:sk_live/features/home/presentation/widgets/room_youtube_picker_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/room_youtube_player_host.dart';
import 'package:sk_live/features/home/services/room_youtube_sync_controller.dart';
import 'package:sk_live/features/home/services/room_shared_audio_sync_controller.dart';
import 'package:sk_live/features/home/services/room_shared_audio_queue_controller.dart';
import 'package:sk_live/features/home/presentation/widgets/room_shared_audio_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/room_shared_audio_floating_player.dart';
import 'package:sk_live/features/home/presentation/widgets/room_win_bonus_card.dart';
import 'package:sk_live/features/home/presentation/widgets/room_lucky_pro_win_overlay.dart';
import 'package:sk_live/features/home/presentation/widgets/room_bonus_patti_overlay.dart';
import 'package:sk_live/features/home/presentation/widgets/room_bonus_multiplier_svga_overlay.dart';
import 'package:sk_live/core/providers/lucky_bonus_multiplier_svgas_provider.dart';
import 'package:sk_live/core/providers/lucky_room_win_svga_provider.dart';
import 'package:sk_live/core/util/room_win_card_util.dart';
import 'package:sk_live/core/widgets/user_badge_chip.dart';
import 'package:sk_live/core/widgets/user_member_identity.dart';
import 'package:sk_live/features/home/presentation/widgets/room_gift_sender.dart';
import 'package:sk_live/features/home/presentation/widgets/room_full_screen_gift.dart';
import 'package:sk_live/features/home/presentation/widgets/room_bottom_toolbar_button.dart';
import 'package:sk_live/features/home/presentation/widgets/room_private_messages_sheet.dart';
import 'package:sk_live/core/providers/notification_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_room_overlay.dart';
import 'package:sk_live/core/providers/team_pk_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/pk/pk_overlay.dart';
import 'package:sk_live/features/home/presentation/widgets/pk/pk_setting_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/room_members_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/room_chat_tabs.dart';
import 'package:sk_live/features/home/presentation/widgets/room_side_float_rail.dart';
import 'package:sk_live/features/home/presentation/widgets/room_contribution_sheet.dart';
import 'package:sk_live/features/home/presentation/pages/gift_center_screen.dart';
import 'package:sk_live/core/providers/room_contribution_provider.dart';
import 'package:sk_live/core/providers/shop_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/team_pk/team_pk_overlay.dart';
import 'package:sk_live/features/home/presentation/widgets/team_pk/team_pk_setting_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/room_mic_emoji_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/room_mic_emoji_overlay.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/util/debug_probe.dart'; // agent log
import 'package:sk_live/core/models/big_gift_patti_announcement.dart';
import 'package:sk_live/core/services/big_gift_patti_broadcast_controller.dart';
import 'package:sk_live/core/util/big_gift_patti_util.dart';
import 'package:sk_live/core/models/global_win_announcement.dart';
import 'package:sk_live/core/services/global_win_broadcast_controller.dart';
import 'package:sk_live/core/services/patti_playback_gate.dart';
import 'package:sk_live/features/home/services/room_live_broadcast.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';
import 'package:sk_live/features/home/services/room_realtime_socket.dart';
import 'package:sk_live/features/home/services/room_zego_sync_service.dart';
import 'package:sk_live/features/home/services/room_seat_sync_service.dart';
import 'package:sk_live/features/home/services/room_win_sync_service.dart';
import 'package:sk_live/core/util/dev_log.dart';

part 'room_live_screen_broadcast.dart';

const double _kSeatBand = 56;
const double _kSeatSoundWave = _kSeatBand * 1.66;

const double _kClassic8Scale = 1.1;

const double _kOwnerModeHostScale = 0.90;
const double _kOwnerModeGuestScale = 0.98;

const String _kRoomEntryWarning =
    'Welcome to Livo\n'
    'Warning! Vulgar, pornographic, violent or underage content is prohibited.\n'
    'Moderators monitor 24/7 — violations will be strictly punished.';

class _PendingRepeatGift {
  _PendingRepeatGift({
    required this.animationBatchId,
    required this.unitCost,
    required this.session,
  });

  final String animationBatchId;

  /// Optimistic coins held for every tap merged into this send.
  int unitCost;
  final RepeatGiftSession session;

  /// Taps merged while an earlier send was in flight; settled as one
  /// gift:send with quantity = session.quantity * taps.
  int taps = 1;

  int get quantity => session.quantity * taps;
}

/// A lucky gift's chat line, parked until its roll stops.
class _PendingLuckyGiftComment {
  _PendingLuckyGiftComment({required this.message, required this.timer});

  final Map<String, dynamic> message;
  final Timer timer;
}

class RoomLiveScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> room;
  const RoomLiveScreen({super.key, required this.room});

  static Future<void> cleanupRoomStatic(
    String roomId,
    String? userId, {
    int? leaveEpoch,
  }) async {
    debugPrint('cleanupRoomStatic called for room: $roomId');
    if (leaveEpoch != null &&
        RoomExitCoordinator.shouldAbortTeardown(roomId, leaveEpoch)) {
      debugPrint(
        'cleanupRoomStatic abort — room $roomId live again (epoch $leaveEpoch)',
      );
      return;
    }
    RoomMinimizedKeepAlive.stop();
    OrbitVoiceSessionService.silenceForExit(roomId: roomId);
    await RoomSharedAudioSyncController.haltPlaybackForRoom(roomId);
    await RoomMediaKeepAlive.disposeAll();
    if (leaveEpoch != null &&
        RoomExitCoordinator.shouldAbortTeardown(roomId, leaveEpoch)) {
      debugPrint('cleanupRoomStatic abort before orbit leave');
      return;
    }
    try {
      await OrbitVoiceSessionService.stopLocalAudioForExit(roomId: roomId);
    } catch (e) {
      debugPrint('cleanupRoomStatic orbit local audio: $e');
    }
    if (leaveEpoch != null &&
        RoomExitCoordinator.shouldAbortTeardown(roomId, leaveEpoch)) {
      return;
    }
    try {
      await OrbitVoiceSessionService.stopPublishAndLeave(roomId: roomId);
    } catch (e) {
      debugPrint('cleanupRoomStatic orbit leave: $e');
    }
    if (leaveEpoch != null &&
        RoomExitCoordinator.shouldAbortTeardown(roomId, leaveEpoch)) {
      return;
    }
    await RoomVoiceSessionService.stopAllRemotePlayback();
    await RoomVoiceSessionService.stopLocalPublish();
    unawaited(RoomVoiceSessionService.logoutRoomFast(roomId));
    try {
      await RoomVoiceSessionService.leaveVoiceRoom(
        roomId,
        userId,
        skipSeatDelete: AppConstants.useRealtimeGateway,
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      debugPrint('cleanupRoomStatic leaveVoiceRoom timed out — force destroy');
      await RoomVoiceSessionService.forceDestroyEngine();
    } catch (e) {
      debugPrint('cleanupRoomStatic leaveVoiceRoom failed: $e');
      await RoomVoiceSessionService.forceDestroyEngine();
    }
    if (leaveEpoch != null &&
        RoomExitCoordinator.shouldAbortTeardown(roomId, leaveEpoch)) {
      return;
    }
    if (AppConstants.useRealtimeGateway && userId != null) {
      try {
        await RoomRealtimeSocket.instance
            .seatLeave({
              'roomId': roomId,
              'user_id': userId,
              'event_id': RoomLiveBroadcast.newEventId(),
            })
            .timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('cleanupRoomStatic gateway seatLeave failed: $e');
      }
      if (leaveEpoch != null &&
          RoomExitCoordinator.shouldAbortTeardown(roomId, leaveEpoch)) {
        return;
      }
      try {
        await RoomRealtimeSocket.instance
            .leaveRoom(roomId: roomId, user: {'id': userId})
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('cleanupRoomStatic gateway leave failed: $e');
      }
    }
  }

  @override
  ConsumerState<RoomLiveScreen> createState() => _RoomLiveScreenState();
}

class _RoomLiveScreenState extends ConsumerState<RoomLiveScreen>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        RouteAware,
        _RoomLiveBroadcastMixin {
  static const int _maxChatMessages = 300;
  static const int _maxGlobalWinMessages = 50;
  static final RegExp _zegoPrefix = RegExp(r'^zego\b', caseSensitive: false);
  final List<Map<String, dynamic>> _messages = [];
  final Set<String> _messageKeys = <String>{};

  /// Lucky gift comments waiting for their roll result, by gift log id.
  final Map<String, _PendingLuckyGiftComment> _pendingLuckyGiftComments = {};

  /// How long a lucky comment waits for its win event before posting plain.
  /// The gateway rolls right after the fan-out, so a win lands well inside it.
  static const Duration _luckyGiftSettleWindow = Duration(seconds: 3);

  final ValueNotifier<int> _chatListVersion = ValueNotifier(0);
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  late RealtimeChannel _roomChannel;
  RealtimeChannel? _globalWinChannel;
  final LinkedHashSet<String> _seenBroadcastEventIds = LinkedHashSet();
  final LinkedHashSet<String> _seenFullScreenGiftBatchIds = LinkedHashSet();
  static const int _maxSeenBroadcastIds = 200;
  bool _roomChannelConnected = false;
  bool _showReconnectBanner = false;
  bool _hadInitialRoomSubscribe = false;
  bool _isLeavingRoom = false;
  bool _roomChannelTeardownDone = false;
  Timer? _reconnectBannerTimer;
  Timer? _seatReconcileTimer;
  Timer? _reconcilePollTimer;
  Timer? _presenceHeartbeatTimer;
  Timer? _presenceSnapshotTimer;
  Timer? _gatewaySnapshotDebounceTimer;
  bool _presenceSnapshotBootstrap = false;
  static const Duration _reconcilePollInterval = Duration(seconds: 12);
  static const Duration _seatReconcileDebounce = Duration(seconds: 4);
  static const Duration _reconnectBannerDelay = Duration(milliseconds: 1200);
  final List<Map<String, dynamic>> _globalWinMessages = [];
  Map<String, dynamic>? _roomData;
  List<Map<String, dynamic>> _seats = [];
  Map<String, int> _seatGiftTotals = {};

  Map<String, String> _cpPartnerByUserId = {};
  int _cpPartnerRefreshGeneration = 0;
  String? _zegoRoomId;
  DateTime? _lastSeatBroadcastAt;
  final Map<String, DateTime> _recentlyVacatedSeatUsers = {};

  final Map<String, DateTime> _snapshotSeatHolds = {};
  static const Duration _snapshotSeatHoldWindow = Duration(seconds: 6);
  final Map<String, String> _remoteStreamIdsByUserId = {};
  final Map<String, double> _soundLevels = {};
  final ValueNotifier<int> _soundLevelsVersion = ValueNotifier(0);
  bool _soundLevelsDisposed = false;
  Timer? _soundLevelsCooldown;
  bool _soundLevelsPending = false;
  static const Duration _soundLevelsFlushInterval = Duration(milliseconds: 100);
  // Resolved LiveKit identity -> seat user id, so a speaker report no longer
  // scans every seat. Bounded so a long session cannot grow it.
  final Map<String, String> _orbitIdentityUserIds = {};
  static const int _orbitIdentityCacheMax = 64;

  final Map<String, bool> _speakSticky = {};
  final Map<String, Timer> _speakHoldTimers = {};
  static const double _speakOnThreshold = 3.0;
  static const double _speakOffThreshold = 1.2;
  static const Duration _speakHoldDuration = Duration(milliseconds: 500);

  String? _sharedAudioSeatPulseUserId;
  bool _sharedAudioSeatPulseListening = false;

  List<Map<String, dynamic>> _audience = [];
  List<Map<String, dynamic>> _onlineUsers = [];

  final Set<String> _knownPresenceUserIds = {};

  final Set<String> _entranceHandledUserIds = {};
  final Set<String> _entranceInFlight = {};
  final Map<String, Timer> _entranceLeaveTimers = {};

  final Map<String, DateTime> _entranceLastShownAt = {};
  static const Duration _entranceEchoCooldown = Duration(seconds: 5);

  void _pruneEntranceLastShownAt() {
    final cutoff = DateTime.now().subtract(_entranceEchoCooldown);
    _entranceLastShownAt.removeWhere((_, at) => at.isBefore(cutoff));
  }

  int _entrancePlaybackToken = 0;
  bool _isEntranceAnimating = false;

  String? _entranceGateToken;

  bool _entranceMediaReady = false;
  bool _entrancePlaybackStarted = false;
  bool _entrancePattiLoaded = false;
  bool _entranceCarLoaded = false;
  GlobalKey<RaveSVGAPlayerState> _entrancePattiSvgaKey =
      GlobalKey<RaveSVGAPlayerState>();
  GlobalKey<RaveSVGAPlayerState> _entranceCarSvgaKey =
      GlobalKey<RaveSVGAPlayerState>();
  bool _initialPresenceSeeded = false;
  bool _isMuted = true;

  bool _isLocalPublishing = false;

  bool _orbitCanPublish = false;

  Future<void> _orbitInitChain = Future.value();

  bool? _orbitInitDesiredMic;

  int _orbitMicIntentGen = 0;

  Future<void> _orbitMicChain = Future.value();
  DateTime? _orbitLastBillingAt;
  bool? _orbitLastBillingOpenMic;
  bool _voiceHealInFlight = false;
  Timer? _voiceHealDebounce;
  // Number of _startSpeaking(true) calls currently running. A snapshot that
  // lands while one is in flight sees "on seat, not publishing yet" and would
  // schedule a heal that re-enters _startSpeaking, bumps the mic intent
  // generation and rolls back the publish that was about to succeed.
  int _startSpeakingOpenInFlight = 0;
  // Last gateway snapshot applied, so the duplicates a join produces (cached
  // seats, full snapshot, and the reply to our own snapshot request) do not
  // each rebuild the whole screen.
  String? _lastSnapshotSignature;
  DateTime? _lastSnapshotAppliedAt;
  // Time from this screen being created to the first seat list from the
  // gateway. Logged once per room open so the one-second target can be checked
  // on a real device instead of guessed.
  final Stopwatch _roomOpenWatch = Stopwatch()..start();
  bool _firstSeatsLogged = false;
  static const Duration _snapshotDedupeWindow = Duration(seconds: 2);

  DateTime? _localUnmuteGuardUntil;

  DateTime? _localMuteGuardUntil;
  int? _mySeatIndexValue;
  // Every change of the user's own seat also tells the voice engine, because an
  // open voice token lets everyone publish and the seat is what decides who may.
  int? get _mySeatIndex => _mySeatIndexValue;
  set _mySeatIndex(int? value) {
    _mySeatIndexValue = value;
    OrbitVoiceSessionService.setSeatPublishAllowed(value != null);
  }
  String _activeTab = 'chat';

  void _notifyChatListChanged() {
    _chatListVersion.value++;
  }

  void _setActiveChatTab(String tab) {
    if (_activeTab == tab) return;
    _activeTab = tab;
    _notifyChatListChanged();
  }

  /// Every identity one chat row can arrive with.
  ///
  /// A gift reaches the room twice: as the socket / broadcast copy, whose `id`
  /// is the gateway's `metadata.event_id`, and as the `room_messages` insert the
  /// gateway writes for history, whose `id` is the row uuid. Keying on `id`
  /// alone made those two different messages, so the gift was listed twice.
  List<String> _chatMessageKeys(Map<String, dynamic> message) {
    final keys = <String>[];
    final id = message['id']?.toString();
    if (id != null && id.isNotEmpty) keys.add('id:$id');
    final meta = message['metadata'];
    if (meta is Map) {
      final eventId = meta['event_id']?.toString();
      // Only gifts carry one event_id on two rows; a lucky_win copy repeats its
      // gift's event_id on purpose, so it keeps keying on its own id.
      final aliasEventId =
          keys.isEmpty || message['type']?.toString() == 'gift';
      if (eventId != null && eventId.isNotEmpty && aliasEventId) {
        keys.add('evt:$eventId');
      }
    }
    return keys;
  }

  /// Reserves a message's keys without listing it yet. Used while a lucky gift
  /// comment waits for its roll, so other copies of the same gift stay out.
  bool _claimChatMessageKeys(Map<String, dynamic> message) {
    final keys = _chatMessageKeys(message);
    if (keys.isEmpty) return true;
    if (keys.any(_messageKeys.contains)) return false;
    _messageKeys.addAll(keys);
    return true;
  }

  bool _tryAppendChatMessage(
    Map<String, dynamic> message, {
    bool scroll = true,
    bool keysClaimed = false,
  }) {
    if (!keysClaimed && !_claimChatMessageKeys(message)) return false;

    _messages.add(message);
    while (_messages.length > _maxChatMessages) {
      final old = _messages.removeAt(0);
      _messageKeys.removeAll(_chatMessageKeys(old));
    }
    _notifyChatListChanged();
    if (scroll) _scrollToBottom();
    return true;
  }

  void _cancelPendingLuckyGiftComments() {
    for (final pending in _pendingLuckyGiftComments.values) {
      pending.timer.cancel();
    }
    _pendingLuckyGiftComments.clear();
  }

  void _clearChatMessages({bool clearGlobalWins = false}) {
    _cancelPendingLuckyGiftComments();
    _messages.clear();
    _messageKeys.clear();
    if (clearGlobalWins) _globalWinMessages.clear();
    _notifyChatListChanged();
  }

  bool _isRoomChatExpanded = false;

  /// Chat bar open/closed. Notifiers so opening the comment field or the
  /// games sheet does not setState the whole room (seats, frames, background).
  final ValueNotifier<bool> _chatBarOpen = ValueNotifier<bool>(false);
  final ValueNotifier<int> _gamesRev = ValueNotifier<int>(0);

  String? _mentionQuery;
  int? _mentionAtIndex;
  List<Map<String, dynamic>> _mentionSuggestions = [];

  final List<Map<String, dynamic>> _pendingMentions = [];
  Map<String, dynamic>? _enteringUser;

  final List<Map<String, dynamic>> _activeLuckyFanbis = [];
  final List<Map<String, dynamic>> _activeLuckyMultipliers = [];
  RoomBonusPattiData? _bonusPatti;
  bool _bonusPattiVisible = false;
  Timer? _bonusPattiHideTimer;

  /// Running gift count per sender while their combo is live, so a lucky
  /// strip opens on the combo so far instead of x1 for the winning gift.
  final Map<String, ({int total, int atMs})> _giftComboBySender = {};

  final LinkedHashSet<String> _seenLuckyFloatKeys = LinkedHashSet();
  int _luckyFloatStackSeq = 0;
  AnimationController? _entranceController;
  Animation<Offset>? _entranceSlideAnimation;
  Animation<double>? _entranceFadeAnimation;
  final FocusNode _chatFocusNode = FocusNode();
  late final RoomYoutubeSyncController _youtubeSync;
  late final RoomSharedAudioSyncController _sharedAudioSync;
  late final RoomSharedAudioQueueController _sharedAudioQueue;

  bool _mediaResumedFromKeepAlive = false;
  Timer? _activityTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _seatsStreamSubscription;
  int _fetchSeatsGeneration = 0;
  String _currentUserRole = 'member';
  List<Map<String, dynamic>> _activeGames = [];
  bool _showExitSidebar = false;
  OverlayEntry? _exitSidebarOverlay;
  int _sidebarDismissBlockedUntil = 0;
  bool _sidebarActionInProgress = false;
  bool _shouldKeepZegoAlive = false;
  bool _canPopRoute = false;
  ModalRoute<void>? _subscribedRoute;
  bool _isAutoMinimizing = false;
  bool _kickHandled = false;
  bool _roomSessionReleased = false;
  bool _resumingMinimizedSession = false;

  int _seatSessionGeneration = 0;
  bool _zegoLoginReady = false;

  VoiceBackend _voiceBackend = VoiceBackend.orbit;
  bool get _useOrbitVoice => true;
  bool _gatewayJoinReady = !AppConstants.useRealtimeGateway;

  double _roomPlayVolume = 100;
  bool _audioRouteToSpeaker = true;

  bool _roomAudioMuted = false;

  String? _activeCarSvga;
  String? _activePattiSvga;
  String? _activePattiUrl;
  Timer? _entranceTimer;

  final List<GlobalKey> _seatKeys = List.generate(20, (_) => GlobalKey());
  final Map<String, GlobalKey> _memberAnchorKeys = {};
  final GlobalKey _audienceKey = GlobalKey();
  final GlobalKey _seatsGridKey = GlobalKey();
  final GlobalKey _bottomToolbarKey = GlobalKey();
  static const double _entranceBannerHeight = 90.0;
  static const double _entranceProfileSize = 36.0;
  static const double _entranceProfileLeftInset = 58.0;
  static const double _entranceProfileTopInsetImage = 38.0;
  static const double _entranceProfileTopInsetSvga = 46.0;
  static const Duration _entranceAnimationDuration = Duration(seconds: 6);
  static const Duration _entranceRejoinCooldown = Duration(seconds: 8);

  String? _normalizePresenceUserId(dynamic id) {
    if (id == null) return null;
    final normalized = id.toString().trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  bool get _hasCustomBackground {
    final url = _roomData?['background_url']?.toString().trim();
    return url != null && url.isNotEmpty;
  }

  /// The gateway and Supabase Realtime both report who is in the room, and both
  /// used to drive entrances and rebuild this screen — so every join cost two
  /// full rebuilds, and the Supabase handler's `_knownPresenceUserIds` reset
  /// fought the gateway's incremental one, which is what double-fired entrance
  /// animations when several people arrived at once.
  ///
  /// The gateway is authoritative: it carries the entrance payload and the car
  /// SVGA. So Supabase presence is only read while the gateway is not carrying
  /// this room. `track()` still runs either way, so app versions that read
  /// Supabase presence keep seeing this user in their audience list.
  bool get _gatewayOwnsPresence {
    if (!AppConstants.useRealtimeGateway) return false;
    final socket = RoomRealtimeSocket.instance;
    return socket.isConnected &&
        socket.isJoinedTo(widget.room['id'].toString());
  }

  List<Map<String, dynamic>> _dedupeOnlineUsersById(
    List<Map<String, dynamic>> users,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final user in users) {
      final id = _normalizePresenceUserId(user['id']);
      if (id == null) continue;
      byId[id] = user;
    }
    return byId.values.toList();
  }

  void _scheduleEntranceRejoinEligibility(String userId) {
    _entranceLeaveTimers[userId]?.cancel();
    _entranceLeaveTimers[userId] = Timer(_entranceRejoinCooldown, () {
      _entranceLeaveTimers.remove(userId);
      _knownPresenceUserIds.remove(userId);
      _entranceHandledUserIds.remove(userId);
      debugPrint(
        '[Entrance] cooldown done uid=$userId — cleared known+handled',
      );
    });
  }

  void _cancelEntranceRejoinEligibility(String userId) {
    final timer = _entranceLeaveTimers.remove(userId);
    if (timer != null) {
      timer.cancel();
      debugPrint('[Entrance] leave cooldown cancelled (rejoin) uid=$userId');
    }
  }

  void _cancelAllEntranceRejoinTimers() {
    for (final timer in _entranceLeaveTimers.values) {
      timer.cancel();
    }
    _entranceLeaveTimers.clear();
  }

  final GiftFlightController _giftFlightController = GiftFlightController();
  final RoomMicEmojiOverlayController _micEmojiOverlayController =
      RoomMicEmojiOverlayController();
  bool _fullScreenGiftShowing = false;
  OverlayEntry? _fullScreenGiftOverlayEntry;
  /// Bounded FS gift queue — drop oldest under storm so busy rooms stay live.
  /// The icon rides along as the fallback when the SVGA cannot be decoded.
  final ListQueue<({String svgaUrl, String iconUrl})> _fullScreenGiftQueue =
      ListQueue<({String svgaUrl, String iconUrl})>();
  static const int _maxFullScreenGiftQueued = 3;
  RepeatGiftSession? _repeatGiftSession;
  bool _isRepeatSending = false;
  bool _repeatGiftDraining = false;
  /// Optimistic coins for the repeat-gift button. Deducted on each tap so a
  /// stale profile stream cannot keep accepting taps past the real balance.
  /// `-1` means "not armed yet — take the next profile read".
  int _giftCoinsLocal = -1;
  DateTime? _lastInsufficientGiftToastAt;
  final ListQueue<_PendingRepeatGift> _repeatGiftQueue =
      ListQueue<_PendingRepeatGift>();
  DateTime? _lastRepeatGiftAt;
  Timer? _repeatGiftHideTimer;

  /// Repeat sends in flight at once.
  ///
  /// send_gift locks the sender's balance row and the gateway queues each
  /// sender's gift:send, so parallel sends only waited in line. With one in
  /// flight, taps made meanwhile merge into the next send (see
  /// [_PendingRepeatGift.taps]): one Postgres transaction and one room
  /// broadcast per round trip instead of per tap, so the room stops replaying
  /// a backlog after the tapper stops.
  static const int _maxRepeatGiftInFlight = 1;

  /// send_gift / gift:notify clamp quantity here.
  static const int _maxRepeatGiftQuantity = 9999;

  /// Taps in the current combo streak, shown on the combo button.
  int _repeatComboCount = 0;

  /// Bumped per tap so the combo button restarts its ring without a
  /// full-screen setState.
  final ValueNotifier<int> _repeatComboTick = ValueNotifier<int>(0);

  bool _seatGiftRebuildScheduled = false;

  /// Ceiling on queued repeat taps. Holding the button must not grow a list
  /// forever; each tap's own animation has already played by then.
  static const int _maxRepeatGiftQueued = 60;

  static const Duration _repeatGiftVisibleFor = Duration(seconds: 3);

  static const Duration _repeatGiftMinInterval = Duration(milliseconds: 40);
  final Set<String> _giftTargetUserIds = {};
  bool _giftTargetAllSelected = false;

  int _roomCurrentLevel() {
    for (final source in [_roomData, widget.room]) {
      if (source == null) continue;
      final stats = source['room_stats'];
      if (stats is Map) {
        return (stats['current_level'] as num?)?.toInt() ?? 1;
      }
      if (stats is List && stats.isNotEmpty) {
        final first = stats.first;
        if (first is Map) {
          return (first['current_level'] as num?)?.toInt() ?? 1;
        }
      }
      final direct = source['current_level'];
      if (direct != null) {
        return (direct as num).toInt();
      }
    }
    return 1;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomData = Map<String, dynamic>.from(widget.room);
    _roomChannel = Supabase.instance.client.channel(
      'room:${widget.room['id']}',
    );
    LuckyRoomSvgaFlagsStore.invalidate();
    unawaited(LuckyRoomSvgaFlagsStore.load(force: true));

    final roomId = widget.room['id'].toString();
    RoomSwitchCoordinator.markEnteringRoom(roomId);
    final minimizedAtLaunch = ref.read(minimizedRoomProvider);
    final sameMinimized =
        minimizedAtLaunch != null &&
        minimizedAtLaunch['id'].toString() == roomId;
    final sameKeepAlive = RoomMinimizedKeepAlive.roomId == roomId;
    final sameSocket =
        AppConstants.useRealtimeGateway &&
        RoomRealtimeSocket.instance.joinedRoomId == roomId;
    _resumingMinimizedSession = sameMinimized || sameKeepAlive || sameSocket;

    if (!_resumingMinimizedSession) {
      OrbitVoiceSessionService.prefetchSession(roomId);
      OrbitVoiceSessionService.claimPrefetch(roomId);
    }

    if (sameMinimized || sameKeepAlive) {
      RoomMinimizedKeepAlive.relinquishOrbitHeal();
    }

    if (!_resumingMinimizedSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final allowed = await ensureRoomUnlockedForEntry(
          context,
          Map<String, dynamic>.from(_roomData ?? widget.room),
        );
        if (!allowed && mounted) {
          Navigator.of(context).maybePop();
        }
      });
    }

    if (_resumingMinimizedSession) {
      final selfId = _normalizePresenceUserId(
        ref.read(userProfileProvider).value?['id'] ??
            Supabase.instance.client.auth.currentUser?.id,
      );
      if (selfId != null) {
        _entranceHandledUserIds.add(selfId);
        _knownPresenceUserIds.add(selfId);
      }
    }

    final resumedMedia = RoomMediaKeepAlive.takeForResume(
      widget.room['id'].toString(),
    );
    if (resumedMedia != null) {
      _mediaResumedFromKeepAlive = true;
      _youtubeSync = resumedMedia.youtube;
      _sharedAudioSync = resumedMedia.sharedAudio;
      _youtubeSync.reattach(
        canManageRoom: () => _canManageRoom,
        onLocalStateUpdate: (state) {
          if (_roomData != null) {
            _roomData!['youtube_state'] = state;
          }
        },
        broadcastState: (state) {
          if (AppConstants.useRealtimeGateway) {
            return RoomRealtimeSocket.instance
                .publish(
                  roomId: widget.room['id'].toString(),
                  event: 'youtube_state',
                  data: Map<String, dynamic>.from(state),
                )
                .then((_) {});
          }
          return _roomChannel.sendBroadcastMessage(
            event: 'youtube_state',
            payload: state,
          );
        },
      );
      _sharedAudioSync.reattach(
        currentUserId: () => Supabase.instance.client.auth.currentUser?.id,
        currentUsername: () {
          final profile = ref.read(userProfileProvider).value;
          return profile?['username']?.toString() ?? 'User';
        },

        canManageRoom: () => _canManageRoom,
        onLocalStateUpdate: (state) {
          if (_roomData != null) {
            _roomData!['shared_audio_state'] = state;
          }
        },
        broadcastState: (state) {
          if (AppConstants.useRealtimeGateway) {
            return RoomRealtimeSocket.instance
                .publish(
                  roomId: widget.room['id'].toString(),
                  event: 'shared_audio_state',
                  data: Map<String, dynamic>.from(state),
                )
                .then((_) {});
          }
          return _roomChannel.sendBroadcastMessage(
            event: 'shared_audio_state',
            payload: state,
          );
        },
      );
      _sharedAudioQueue =
          resumedMedia.sharedAudioQueue ??
          RoomSharedAudioQueueController(
            roomId: widget.room['id'].toString(),
            sync: _sharedAudioSync,
          );
      _sharedAudioQueue.bindSync(_sharedAudioSync);
      unawaited(_sharedAudioQueue.ensureReady());
      _attachSharedAudioSeatPulseListener();
    } else {
      _youtubeSync = RoomYoutubeSyncController(
        roomId: widget.room['id'].toString(),
        canManageRoom: () => _canManageRoom,
        onLocalStateUpdate: (state) {
          if (_roomData != null) {
            _roomData!['youtube_state'] = state;
          }
        },
        broadcastState: (state) {
          if (AppConstants.useRealtimeGateway) {
            return RoomRealtimeSocket.instance
                .publish(
                  roomId: widget.room['id'].toString(),
                  event: 'youtube_state',
                  data: Map<String, dynamic>.from(state),
                )
                .then((_) {});
          }
          return _roomChannel.sendBroadcastMessage(
            event: 'youtube_state',
            payload: state,
          );
        },
      );

      _sharedAudioSync = RoomSharedAudioSyncController(
        roomId: widget.room['id'].toString(),
        currentUserId: () => Supabase.instance.client.auth.currentUser?.id,
        currentUsername: () {
          final profile = ref.read(userProfileProvider).value;
          return profile?['username']?.toString() ?? 'User';
        },

        canManageRoom: () => _canManageRoom,
        onLocalStateUpdate: (state) {
          if (_roomData != null) {
            _roomData!['shared_audio_state'] = state;
          }
        },
        broadcastState: (state) {
          if (AppConstants.useRealtimeGateway) {
            return RoomRealtimeSocket.instance
                .publish(
                  roomId: widget.room['id'].toString(),
                  event: 'shared_audio_state',
                  data: Map<String, dynamic>.from(state),
                )
                .then((_) {});
          }
          return _roomChannel.sendBroadcastMessage(
            event: 'shared_audio_state',
            payload: state,
          );
        },
      );
      _sharedAudioQueue = RoomSharedAudioQueueController(
        roomId: widget.room['id'].toString(),
        sync: _sharedAudioSync,
      );
      unawaited(_sharedAudioQueue.ensureReady());
      _attachSharedAudioSeatPulseListener();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(currentLiveRoomIdProvider.notifier).state = roomId;
      RoomExitCoordinator.noteRoomLive(roomId);
      if (minimizedAtLaunch != null) {
        ref.read(minimizedRoomProvider.notifier).state = null;
      }
      ref.read(roomSystemBubbleVisibleProvider.notifier).state = false;
      syncActiveRoomSession(ref, _roomData ?? widget.room);
      unawaited(
        RoomFloatingBubbleService.hideRoomBubble(
          reason: RoomBubbleHideReason.appResumed,
        ),
      );
      unawaited(
        RoomSwitchCoordinator.prepareEnterRoom(
          ref: ref,
          enteringRoomId: roomId,
          retainResumedMedia: _mediaResumedFromKeepAlive,
        ),
      );
    });

    _entranceController = AnimationController(
      vsync: this,
      duration: _entranceAnimationDuration,
    );

    _entranceSlideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(1.0, 0.0)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      TweenSequenceItem(tween: ConstantTween<Offset>(Offset.zero), weight: 41),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-1.5, 0.0),
        ).chain(CurveTween(curve: Curves.easeInQuint)),
        weight: 29,
      ),
    ]).animate(_entranceController!);

    _entranceFadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 8),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 48),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 29),
    ]).animate(_entranceController!);

    if (AppConstants.useRealtimeGateway) {
      RoomRealtimeSocket.instance.onSnapshot = (snap) {
        if (!mounted) return;
        _applyGatewaySnapshot(snap);
      };
    }

    _initSeats(
      source: _resumingMinimizedSession ? 'minimize_resume' : 'fresh_entry',
    );
    if (_resumingMinimizedSession) {
      _restoreMinimizedVoiceState();
      RoomMinimizedKeepAlive.stop();
    } else {
      unawaited(_clearStaleSeatOnFreshEntry());
    }
    // Paint the room first. Ban check still runs before voice, chat, and
    // games — just after the cover frame, not before the route can appear.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkRoomKickBan();
      _initZego();
      _setupRoomSubscriptions();
      if (!AppConstants.useRealtimeGateway) {
        _startReconcilePoll();
      }
      _setupGlobalWinSubscription();
      _loadChatAndWelcome();
      // The games sheet is not visible at entry. Parsing its catalog competes
      // with the LiveKit signalling and the first seat snapshot for the main
      // isolate, so it waits until the entry burst has settled.
      Future<void>.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) _fetchActiveGames();
      });
      // Gift sheet used to fetch once per category on first open. Warm the
      // shared catalog (and first-page icons) after the room settle so the
      // gift button is ready when the user taps it.
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) warmGiftCatalog(ref);
      });
      _fetchCurrentUserRole();
      _startActivityTimer();
      unawaited(_fetchRoomLevelStats());
      ref.read(recentRoomsProvider.notifier).addRoom(widget.room);
      unawaited(_ensureMicPermissionAtEntry());
      unawaited(_ensureRoomShortIdLoaded());
    });

    _chatFocusNode.addListener(() {
      if (!mounted) return;
      final focused = _chatFocusNode.hasFocus;
      if (!focused) _isRoomChatExpanded = false;
      final open = focused || _isRoomChatExpanded;
      if (_chatBarOpen.value != open) _chatBarOpen.value = open;
    });

    _messageController.addListener(_onRoomChatTextChanged);

    BackgroundService.start();
    BackgroundService.updateNotification(
      'LIVO: Room is active',
      'You are in ${_roomData!['title']} — tap to return',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void> && route != _subscribedRoute) {
      roomRouteObserver.unsubscribe(this);
      _subscribedRoute = route;
      roomRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _maybeAutoMinimizeForCoveringRoute();
  }

  Route<dynamic>? _topNavigatorRoute() {
    Route<dynamic>? top;
    Navigator.of(context).popUntil((route) {
      top = route;
      return true;
    });
    return top;
  }

  void _maybeAutoMinimizeForCoveringRoute() {
    if (!mounted || _shouldKeepZegoAlive || _isAutoMinimizing || _canPopRoute) {
      return;
    }
    if (_sidebarActionInProgress) return;

    if (ref.read(authRecoveryInProgressProvider)) return;
    if (_isAuthFlowGoRouterLocation()) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _shouldKeepZegoAlive ||
          _isAutoMinimizing ||
          _canPopRoute) {
        return;
      }
      if (ref.read(authRecoveryInProgressProvider)) return;
      if (_isAuthFlowGoRouterLocation()) return;

      final myRoute = ModalRoute.of(context);
      final topRoute = _topNavigatorRoute();
      if (myRoute == null || topRoute == null || topRoute == myRoute) return;
      if (topRoute is PopupRoute) return;

      if (RoomSwitchCoordinator.isSwitchingToAnotherLiveRoom(
        widget.room['id'].toString(),
      )) {
        unawaited(_leaveForCoveringLiveRoom(autoTriggered: true));
        return;
      }

      unawaited(_minimizeRoomKeepingSession(autoTriggered: true));
    });
  }

  Future<void> _leaveForCoveringLiveRoom({required bool autoTriggered}) async {
    if (!mounted || _isLeavingRoom || _shouldKeepZegoAlive) return;
    if (_isAutoMinimizing) return;

    _isLeavingRoom = true;
    _canPopRoute = true;
    _shouldKeepZegoAlive = false;

    final roomId = widget.room['id'].toString();
    final myId = Supabase.instance.client.auth.currentUser?.id;

    await RoomSharedAudioSyncController.haltPlaybackForRoom(roomId);
    try {
      await RoomLiveScreen.cleanupRoomStatic(roomId, myId);
    } catch (e) {
      debugPrint('[ROOM] switch cleanup failed: $e');
    }

    if (!mounted || !autoTriggered) return;

    final navigator = Navigator.of(context);
    final roomRoute = _subscribedRoute ?? ModalRoute.of(context);
    if (roomRoute != null) {
      navigator.removeRoute(roomRoute);
    }
  }

  bool _isAuthFlowGoRouterLocation() {
    try {
      final loc = GoRouterState.of(context).matchedLocation;
      if (loc == AppRouter.splash) return true;
      if (loc == AppRouter.login || loc.startsWith('${AppRouter.login}/')) {
        return true;
      }
      if (loc == AppRouter.otp) return true;
      if (loc == AppRouter.banned) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  bool _profileRetryUsed = false;

  Future<void> _setupRoomSubscriptionsWhenProfileReady() async {
    if (_profileRetryUsed) return;
    _profileRetryUsed = true;
    // Waiting on the provider's future was not enough. While the saved login
    // is still being restored after a cold start the provider answers null
    // straight away, so that await returned at once, the retry below was
    // already spent, and the room never joined the gateway: no seats and no
    // events until the user left and came back. Wait for an actual profile.
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (mounted && ref.read(userProfileProvider).value == null) {
      if (DateTime.now().isAfter(deadline)) {
        debugPrint('[SEAT] profile unavailable, room realtime not started');
        _profileRetryUsed = false;
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    _setupRoomSubscriptions();
  }

  void _setupRoomSubscriptions() {
    final myUser = ref.read(userProfileProvider).value;
    if (myUser == null) {
      // The profile is normally warm by the time a room opens, but on a cold
      // start it is not. This used to return and never retry, so the gateway
      // was never joined and no seat snapshot ever arrived — seats stayed
      // empty until the user backed out and re-entered.
      unawaited(_setupRoomSubscriptionsWhenProfileReady());
      return;
    }

    if (AppConstants.useRealtimeGateway) {
      unawaited(_setupGatewayRealtime(myUser));
      _roomChannel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'room_kicks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: widget.room['id'],
        ),
        callback: (payload) {
          final kickedId = payload.newRecord['user_id']?.toString();
          if (kickedId == myUser['id']) {
            _handleKickedFromRoom(payload.newRecord['reason']?.toString());
          }
        },
      );
      _roomChannel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'rooms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: widget.room['id'],
        ),
        callback: (payload) {
          if (!mounted) return;
          _applyRoomsPostgresUpdate(
            Map<String, dynamic>.from(payload.newRecord),
          );
        },
      );
      _roomChannel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'room_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: widget.room['id'],
        ),
        callback: (payload) {
          if (!mounted) return;
          _onRoomMessagePostgresReconcile(payload.newRecord);
        },
      );
      _roomChannel.subscribe((status, error) async {
        if (_isLeavingRoom) return;
        if (status == RealtimeSubscribeStatus.subscribed) {
          _reconnectBannerTimer?.cancel();
          if (mounted) {
            setState(() {
              _roomChannelConnected = true;
              _showReconnectBanner = false;
            });
          }
          _hadInitialRoomSubscribe = true;
          return;
        }
        final lostConnection =
            status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut ||
            status == RealtimeSubscribeStatus.closed;
        if (!lostConnection || !_hadInitialRoomSubscribe || _isLeavingRoom) {
          return;
        }
        if (mounted) setState(() => _roomChannelConnected = false);
        _scheduleReconnectBanner();
      });
      return;
    }

    _roomChannel.onBroadcast(
      event: 'shared_audio_state',
      callback: (payload) {
        if (!mounted) return;
        final state = _parseRoomJsonField(payload['payload'] ?? payload);
        if (state != null) {
          _applyRemoteSharedAudioState(state);
        }
      },
    );

    _roomChannel.onBroadcast(
      event: 'youtube_state',
      callback: (payload) {
        if (!mounted) return;
        final state = _parseRoomJsonField(payload['payload'] ?? payload);
        if (state != null) {
          _applyRemoteYoutubeState(state);
        }
      },
    );

    _setupRoomBroadcastListeners();

    _roomChannel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'room_seats',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: widget.room['id'],
      ),
      callback: (payload) {
        if (!mounted || _isLeavingRoom) return;
        _scheduleSeatReconcile();
      },
    );

    _roomChannel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'room_kicks',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: widget.room['id'],
      ),
      callback: (payload) {
        final kickedId = payload.newRecord['user_id']?.toString();
        if (kickedId == myUser['id']) {
          _handleKickedFromRoom(payload.newRecord['reason']?.toString());
        }
      },
    );

    _roomChannel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'rooms',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.room['id'],
      ),
      callback: (payload) {
        if (!mounted) return;
        _applyRoomsPostgresUpdate(Map<String, dynamic>.from(payload.newRecord));
      },
    );

    _roomChannel.onPresenceSync((payload) {
      if (_gatewayOwnsPresence) return;
      final states = _roomChannel.presenceState();
      final onlineUsers = <Map<String, dynamic>>[];
      final newPresenceIds = <String>{};
      final selfId = _normalizePresenceUserId(
        ref.read(userProfileProvider).value?['id'] ??
            Supabase.instance.client.auth.currentUser?.id,
      );

      for (final state in states) {
        for (final presence in state.presences) {
          final payloadMap = Map<String, dynamic>.from(presence.payload);
          onlineUsers.add(payloadMap);
          final id = _normalizePresenceUserId(payloadMap['id']);
          if (id != null) newPresenceIds.add(id);
        }
      }

      if (!_initialPresenceSeeded) {
        _initialPresenceSeeded = true;
        for (final id in newPresenceIds) {
          _knownPresenceUserIds.add(id);
          if (id != selfId) {
            _entranceHandledUserIds.add(id);
          }
        }
      } else {
        for (final id in newPresenceIds) {
          _cancelEntranceRejoinEligibility(id);

          if (_entranceHandledUserIds.contains(id)) {
            continue;
          }

          if (!_knownPresenceUserIds.contains(id)) {
            Map<String, dynamic>? joinedUser;
            for (final u in onlineUsers) {
              if (_normalizePresenceUserId(u['id']) == id) {
                joinedUser = u;
                break;
              }
            }
            if (joinedUser != null) {
              _triggerEntranceShow(
                id,
                joinedUser['username']?.toString() ?? 'User',
              );
            }
          }
        }

        final leftIds = _knownPresenceUserIds.difference(newPresenceIds);
        for (final id in leftIds) {
          _scheduleEntranceRejoinEligibility(id);
        }
      }

      _knownPresenceUserIds
        ..clear()
        ..addAll(newPresenceIds);

      if (mounted) {
        setState(() {
          _onlineUsers = _dedupeOnlineUsersById(onlineUsers);
          _updateAudienceList();
        });
      }
    });

    _roomChannel.subscribe((status, error) async {
      if (_isLeavingRoom) return;

      if (status == RealtimeSubscribeStatus.subscribed) {
        _reconnectBannerTimer?.cancel();
        if (mounted) {
          setState(() {
            _roomChannelConnected = true;
            _showReconnectBanner = false;
          });
        }

        await _roomChannel.track({
          'id': myUser['id'],
          'username': myUser['username'],
          'avatar_url': myUser['avatar_url'],
        });

        if (_hadInitialRoomSubscribe) {
          unawaited(_fetchSeats(refreshGiftTotals: false));
          unawaited(_fetchMessages());
        }
        _hadInitialRoomSubscribe = true;

        final selfId = _normalizePresenceUserId(myUser['id']);
        if (selfId != null) {
          _knownPresenceUserIds.add(selfId);
          if (_resumingMinimizedSession) {
            _entranceHandledUserIds.add(selfId);
            debugPrint('[Entrance] skip self on minimize resume uid=$selfId');
          } else {
            _triggerEntranceShow(
              selfId,
              myUser['username']?.toString() ?? 'User',
            );
          }
        }

        _sharedAudioSync.startRemoteSync();
        _youtubeSync.startRemoteSync();

        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _isLeavingRoom) return;
          if (_gatewayOwnsPresence) return;
          final states = _roomChannel.presenceState();
          final onlineUsers = <Map<String, dynamic>>[];
          for (final state in states) {
            for (final presence in state.presences) {
              onlineUsers.add(Map<String, dynamic>.from(presence.payload));
            }
          }
          setState(() {
            _onlineUsers = _dedupeOnlineUsersById(onlineUsers);
            _updateAudienceList();
          });
        });
        return;
      }

      final lostConnection =
          status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut ||
          status == RealtimeSubscribeStatus.closed;
      if (!lostConnection || !_hadInitialRoomSubscribe || _isLeavingRoom) {
        return;
      }

      if (mounted) {
        setState(() => _roomChannelConnected = false);
      }
      _scheduleReconnectBanner();
    });
  }

  void _applyRoomsPostgresUpdate(Map<String, dynamic> newRecord) {
    final newYt = _parseRoomJsonField(newRecord['youtube_state']);
    final oldYt = _parseRoomJsonField(_roomData?['youtube_state']);

    if (newYt != null && !_youtubeStatesEqual(oldYt, newYt)) {
      _applyRemoteYoutubeState(newYt);
    }

    final newAudio = _parseRoomJsonField(newRecord['shared_audio_state']);
    final oldAudio = _parseRoomJsonField(_roomData?['shared_audio_state']);

    if (newAudio != null && !_sharedAudioStatesEqual(oldAudio, newAudio)) {
      _applyRemoteSharedAudioState(newAudio);
    }

    final micCountChanged = newRecord['mic_count'] != _roomData?['mic_count'];
    final needsUiRefresh =
        micCountChanged ||
        newRecord['party_mode'] != _roomData?['party_mode'] ||
        newRecord['decoration_id'] != _roomData?['decoration_id'] ||
        newRecord['background_url'] != _roomData?['background_url'] ||
        newRecord['admin_only_chat'] != _roomData?['admin_only_chat'] ||
        newRecord['show_spending'] != _roomData?['show_spending'] ||
        newRecord['is_locked'] != _roomData?['is_locked'] ||
        newRecord['announcement'] != _roomData?['announcement'] ||
        newRecord['title'] != _roomData?['title'] ||
        newRecord['chat_cleared_at'] != _roomData?['chat_cleared_at'];

    if (!needsUiRefresh) return;

    setState(() {
      _roomData!['mic_count'] = newRecord['mic_count'];
      _roomData!['party_mode'] = newRecord['party_mode'];
      _roomData!['decoration_id'] = newRecord['decoration_id'];
      _roomData!['background_url'] = newRecord['background_url'];
      if (newYt != null) {
        _roomData!['youtube_state'] = newYt;
      }
      _roomData!['admin_only_chat'] = newRecord['admin_only_chat'];
      if (newRecord.containsKey('show_spending')) {
        _roomData!['show_spending'] = newRecord['show_spending'] == true;
      }
      if (newRecord.containsKey('is_locked')) {
        _roomData!['is_locked'] = newRecord['is_locked'] == true;
      }
      if (newRecord.containsKey('announcement')) {
        _roomData!['announcement'] = newRecord['announcement'];
      }
      if (newRecord['title'] != null) {
        _roomData!['title'] = newRecord['title'];
      }

      final newCleared = newRecord['chat_cleared_at'];
      if (newCleared != null) {
        final newClearedDate = DateTime.tryParse(newCleared.toString());
        final oldClearedDate = DateTime.tryParse(
          _roomData!['chat_cleared_at']?.toString() ?? '',
        );
        if (newClearedDate != null &&
            (oldClearedDate == null ||
                !newClearedDate.isAtSameMomentAs(oldClearedDate))) {
          _roomData!['chat_cleared_at'] = newCleared;
          _clearChatMessages(clearGlobalWins: true);
        }
      }
    });
    devLog('UI_REFRESHING_WITH_COUNT: ${_roomData!['mic_count']}');
    if (micCountChanged) {
      _initSeats(source: 'rooms_postgres_update');
    }
  }

  Future<void> _setupGatewayRealtime(Map<String, dynamic> myUser) async {
    final roomId = widget.room['id'].toString();
    _gatewayJoinReady = false;
    final socket = RoomRealtimeSocket.instance;
    socket.onEvent = (event, data) {
      if (!mounted) return;
      _dispatchGatewayRoomEvent(event, data);
    };
    socket.onSnapshot = (snap) {
      if (!mounted) return;
      _applyGatewaySnapshot(snap);
    };

    try {
      await socket.ensureConnected();
      final userPayload = {
        'id': myUser['id'],
        'username': myUser['username'],
        'avatar_url': myUser['avatar_url'],
      };

      _presenceSnapshotBootstrap = true;
      _presenceSnapshotTimer?.cancel();
      _presenceSnapshotTimer = Timer(const Duration(seconds: 3), () {
        _presenceSnapshotBootstrap = false;
      });

      devLog('[SEAT] gateway joinRoom start room=$roomId');
      final joinSw = Stopwatch()..start();
      final joinRes = await socket.joinRoom(roomId: roomId, user: userPayload);
      if (joinRes?['ok'] != true) {
        final err = joinRes?['error']?.toString() ?? 'join_failed';
        devLog('[SEAT] gateway joinRoom FAIL: $err');
        _gatewayJoinReady = false;
        if (err == 'kicked_from_room' && mounted) {
          _handleKickedFromRoom(
            'You are banned from this room until the kick expires.',
          );
        }
        return;
      }
      _gatewayJoinReady = true;
      devLog(
        '[SEAT] gateway joinRoom OK ms=${joinSw.elapsedMilliseconds} '
        'joined=${socket.joinedRoomId}',
      );

      final selfId = _normalizePresenceUserId(myUser['id']);
      if (mounted && selfId != null) {
        setState(() {
          _onlineUsers = _dedupeOnlineUsersById([..._onlineUsers, userPayload]);
          _knownPresenceUserIds.add(selfId);
          _updateAudienceList();
        });
      }

      if (_resumingMinimizedSession) {
        if (selfId != null) _entranceHandledUserIds.add(selfId);
        debugPrint('[Entrance] skip self on minimize resume (gateway)');
      } else {
        unawaited(
          _triggerEntranceShow(
            myUser['id'].toString(),
            myUser['username']?.toString() ?? 'User',
          ),
        );
      }

      _presenceHeartbeatTimer?.cancel();
      _presenceHeartbeatTimer = Timer.periodic(const Duration(seconds: 40), (
        _,
      ) {
        if (socket.joinedRoomId != roomId) return;
        if (_isLeavingRoom || _shouldKeepZegoAlive) return;
        unawaited(socket.heartbeat(roomId: roomId, user: userPayload));
      });
      unawaited(socket.heartbeat(roomId: roomId, user: userPayload));
    } catch (e) {
      _gatewayJoinReady = false;
      devLog('[SEAT] gateway joinRoom FAIL: $e');
      final msg = e.toString();
      if (msg.contains('kicked_from_room') && mounted) {
        _handleKickedFromRoom(
          'You are banned from this room until the kick expires.',
        );
      }
    }

    _sharedAudioSync.startRemoteSync();
    _youtubeSync.startRemoteSync();
  }

  void _dispatchGatewayRoomEvent(String event, Map<String, dynamic> data) {
    final payload = RoomLiveBroadcast.unwrapPayload(data);
    final eventRoomId =
        payload['room_id']?.toString() ?? data['room_id']?.toString() ?? '';
    final currentRoomId = widget.room['id']?.toString() ?? '';
    if (eventRoomId.isNotEmpty &&
        currentRoomId.isNotEmpty &&
        eventRoomId != currentRoomId) {
      debugPrint(
        '[Gateway] drop cross-room event=$event '
        'eventRoom=$eventRoomId current=$currentRoomId',
      );
      return;
    }
    switch (event) {
      case RoomLiveBroadcast.eventSeat:
        // #region agent log
        DebugProbe.log('D', 'room_live_screen:_dispatchGatewayRoomEvent', 'seat event received', {
          'action': payload['action']?.toString(),
          'seat': payload['seat_index'],
          'actor8': (payload['actor_user_id']?.toString() ?? '-').padRight(8).substring(0, 8),
        });
        // #endregion
        _applySeatBroadcast(payload);
      case RoomLiveBroadcast.eventMeta:
        _handleRoomMetaBroadcast(payload);
      case RoomLiveBroadcast.eventChat:
        _handleRoomChatBroadcast(payload);
      case RoomLiveBroadcast.eventEmoji:
        _handleRoomMicEmojiBroadcast(payload);
      case RoomLiveBroadcast.eventGift:
        _handleRoomGiftBroadcast(payload);
      case RoomLiveBroadcast.eventPresence:
        _applyGatewayPresenceEvent(payload);
      case RoomLiveBroadcast.eventEntrance:
        debugPrint('[Entrance] gateway event room_entrance');
        _handleRoomEntranceBroadcast(payload);
      case RoomLiveBroadcast.kick:
      case RoomLiveBroadcast.eventKick:
        _handleRoomKickBroadcast(payload);
      case RoomLiveBroadcast.luckyWin:
        _handleRoomLuckyWinBroadcast(payload);
      case 'lucky_win':
        _handleGatewayLuckyWinSocket(payload);
      case 'youtube_state':
        _applyRemoteYoutubeState(payload);
      case 'shared_audio_state':
        _applyRemoteSharedAudioState(payload);
      default:
        debugPrint('[Gateway] unhandled event=$event');
    }
  }

  void _applyGatewayPresenceEvent(Map<String, dynamic> payload) {
    final action = payload['action']?.toString();
    final userRaw = payload['user'];
    if (userRaw is! Map) return;
    final user = Map<String, dynamic>.from(userRaw);
    final userId = _normalizePresenceUserId(
      user['id'] ?? payload['actor_user_id'] ?? payload['user_id'],
    );
    if (userId == null) return;

    final selfId = _normalizePresenceUserId(
      ref.read(userProfileProvider).value?['id'] ??
          Supabase.instance.client.auth.currentUser?.id,
    );

    if (action == 'leave') {
      _entranceHandledUserIds.remove(userId);
      _knownPresenceUserIds.remove(userId);
      _scheduleEntranceRejoinEligibility(userId);
      debugPrint(
        '[Entrance] leave uid=$userId '
        'handled=${_entranceHandledUserIds.contains(userId)} '
        'known=${_knownPresenceUserIds.contains(userId)}',
      );
      if (mounted) {
        setState(() {
          _onlineUsers = _onlineUsers
              .where((u) => _normalizePresenceUserId(u['id']) != userId)
              .toList();
          _updateAudienceList();
        });
      }
      return;
    }

    _cancelEntranceRejoinEligibility(userId);
    final isNew = !_knownPresenceUserIds.contains(userId);
    _knownPresenceUserIds.add(userId);

    if (_presenceSnapshotBootstrap && userId != selfId) {
      _entranceHandledUserIds.add(userId);
    }

    if (mounted) {
      setState(() {
        _onlineUsers = _dedupeOnlineUsersById([..._onlineUsers, user]);
        _updateAudienceList();
      });
    }

    debugPrint(
      '[Entrance] presence action=${action ?? "join"} uid=$userId '
      'isNew=$isNew self=${userId == selfId} '
      'bootstrap=$_presenceSnapshotBootstrap '
      'handled=${_entranceHandledUserIds.contains(userId)}',
    );

    if (!isNew || userId == selfId || _presenceSnapshotBootstrap) {
      debugPrint(
        '[Entrance] presence skip show uid=$userId '
        '(isNew=$isNew self=${userId == selfId} '
        'bootstrap=$_presenceSnapshotBootstrap)',
      );
      return;
    }

    final enteringUsername = user['username']?.toString() ?? 'User';

    _addLocalSystemMessage(
      '$enteringUsername entered the room',
      aboutUserId: userId,
    );

    final carSvga =
        payload['car_svga']?.toString() ?? payload['carSvga']?.toString();
    final pattiSvga =
        payload['patti_svga']?.toString() ?? payload['pattiSvga']?.toString();
    final pattiUrl =
        payload['patti_url']?.toString() ?? payload['pattiUrl']?.toString();
    if (carSvga != null || pattiSvga != null || pattiUrl != null) {
      unawaited(
        _showEntranceFromBroadcast(
          userId: userId,
          username: enteringUsername,
          userProfile: user,
          carSvga: carSvga,
          pattiSvga: pattiSvga,
          pattiUrl: pattiUrl,
        ),
      );
    } else {
      unawaited(_triggerEntranceShow(userId, enteringUsername));
    }
  }

  void _applyGatewaySnapshot(Map<String, dynamic> snap) {
    final snapRoom = snap['room_id']?.toString() ?? '';
    final roomId = widget.room['id']?.toString() ?? '';
    if (snapRoom.isNotEmpty && roomId.isNotEmpty && snapRoom != roomId) {
      return;
    }
    // A join delivers the same seat list several times within a second. The
    // window is short so a later identical snapshot still gets to expire seat
    // holds and re-run the heal checks below.
    final signature = jsonEncode(snap);
    final now = DateTime.now();
    final lastAt = _lastSnapshotAppliedAt;
    if (signature == _lastSnapshotSignature &&
        lastAt != null &&
        now.difference(lastAt) < _snapshotDedupeWindow) {
      devLog('[SEAT] snapshot identical — skip');
      return;
    }
    _lastSnapshotSignature = signature;
    _lastSnapshotAppliedAt = now;
    final seatsRaw = snap['seats'];
    if (seatsRaw is List) {
      if (!_firstSeatsLogged) {
        _firstSeatsLogged = true;
        final ms = _roomOpenWatch.elapsedMilliseconds;
        debugPrint('[ROOM-OPEN] first seats ms=$ms seated=${seatsRaw.length}');
        if (ms > 1000) AppTelemetry.log('SLOW room_first_seats ${ms}ms');
      }
      final occupied = seatsRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final byIndex = <int, Map<String, dynamic>>{};
      for (final s in occupied) {
        final idx =
            (s['seat_index'] as num?)?.toInt() ?? (s['index'] as num?)?.toInt();
        if (idx == null || idx < 0) continue;
        byIndex[idx] = s;
      }

      final micCount =
          (_roomData?['mic_count'] ?? widget.room['mic_count']) ?? 8;
      final myId = Supabase.instance.client.auth.currentUser?.id;
      final recentLocalSeat = RoomSeatSyncService.shouldSkipFetch(
        _lastSeatBroadcastAt,
      );
      final prevMy = _mySeatIndex;
      final prevMuted = _isMuted;
      final holdsBefore = _snapshotSeatHolds.length;
      SeatWearCache.ingestSeats(occupied);
      devLog(
        '[SEAT] snapshot seats=${occupied.length} prevMy=$prevMy '
        'recentClaimWindow=$recentLocalSeat',
      );

      if (mounted) {
        setState(() {
          if (_seats.length != micCount) {
            _seats = List.generate(micCount, (index) {
              if (index < _seats.length) {
                final preserved = Map<String, dynamic>.from(_seats[index]);
                preserved['index'] = index;
                return preserved;
              }
              return {
                'index': index,
                'user_id': null,
                'user': null,
                'is_muted': false,
                'is_locked': false,
              };
            });
          }

          int? mySeat;
          var muted = _isMuted;

          final snapshotUserIds = <String>{};
          for (final row in byIndex.values) {
            final uid = _normalizePresenceUserId(row['user_id']);
            if (uid != null) snapshotUserIds.add(uid);
          }

          for (var i = 0; i < _seats.length; i++) {
            final row = byIndex[i];
            final local = _seats[i];
            if (row == null) {
              final localUid = _normalizePresenceUserId(local['user_id']);
              final holdKey = '$i:$localUid';
              final heldSince = _snapshotSeatHolds[holdKey];
              final holdExpired =
                  heldSince != null &&
                  DateTime.now().difference(heldSince) >
                      _snapshotSeatHoldWindow;
              final holdOccupant =
                  localUid != null &&
                  !holdExpired &&
                  !RoomSeatSyncService.wasRecentlyVacated(
                    _recentlyVacatedSeatUsers,
                    localUid,
                  ) &&
                  !snapshotUserIds.contains(localUid);
              if (holdOccupant ||
                  _shouldPreserveLocalSeatOccupant(local) ||
                  (recentLocalSeat && localUid != null)) {
                if (local['user_id']?.toString() == myId) {
                  mySeat = i;
                  muted = local['is_muted'] == true;
                }
                if (holdOccupant) {
                  _snapshotSeatHolds[holdKey] ??= DateTime.now();
                  devLog('[SEAT] snapshot HOLD index=$i user=$localUid');
                }
                continue;
              }
              if (localUid != null &&
                  _snapshotSeatHolds.remove(holdKey) != null) {
                devLog(
                  '[SEAT] snapshot CLEAR index=$i user=$localUid (hold expired)',
                );
              }
              final locked = local['is_locked'] == true;
              _seats[i] = {
                'index': i,
                'user_id': null,
                'user': null,
                'is_muted': false,
                'is_locked': locked,
              };
              continue;
            }
            _snapshotSeatHolds.removeWhere((k, _) => k.startsWith('$i:'));
            if (_shouldPreserveLocalSeatOccupant(local, row)) {
              if (row['is_muted'] != null) {
                local['is_muted'] = row['is_muted'] == true;
              }
              if (row.containsKey('is_locked')) {
                local['is_locked'] = row['is_locked'] == true;
              }
              if (local['user_id']?.toString() == myId) {
                mySeat = i;
                muted = local['is_muted'] == true;
              }
              continue;
            }
            final merged = Map<String, dynamic>.from(row);
            merged['index'] = i;
            if (merged['user'] == null && merged['user_id'] != null) {
              merged['user'] = {
                'id': merged['user_id'],
                'username': merged['username'],
                'avatar_url': merged['avatar_url'],
                'vip_level': merged['vip_level'],
              };
            }
            _seats[i] = merged;
            if (merged['user_id']?.toString() == myId) {
              mySeat = i;
              muted = merged['is_muted'] == true;
            }
          }

          if (mySeat == null &&
              _mySeatIndex != null &&
              _mySeatIndex! < _seats.length &&
              _seats[_mySeatIndex!]['user_id']?.toString() == myId) {
            mySeat = _mySeatIndex;
          }

          if (mySeat == null &&
              recentLocalSeat &&
              prevMy != null &&
              prevMy < _seats.length) {
            devLog(
              '[SEAT] snapshot PRESERVE self during claim window prevMy=$prevMy '
              'occupied=${occupied.length}',
            );
            mySeat = prevMy;
            final seat = _seats[prevMy];
            if (_normalizePresenceUserId(seat['user_id']) == null &&
                myId != null) {
              final profile = ref.read(userProfileProvider).value;
              _seats[prevMy] = {
                ...Map<String, dynamic>.from(seat),
                'user_id': myId,
                'user': {
                  'id': myId,
                  'username': profile?['username'],
                  'avatar_url': profile?['avatar_url'],
                  'vip_level': profile?['vip_level'],
                },
                'is_muted': _isMuted,
                'is_locked': false,
              };
              muted = _isMuted;
              devLog('[SEAT] snapshot restored wiped self occupant at $prevMy');
            }
          }

          _mySeatIndex = mySeat;
          final unmuteGuarded =
              !_isMuted &&
              prevMuted == false &&
              muted == true &&
              _localUnmuteGuardUntil != null &&
              DateTime.now().isBefore(_localUnmuteGuardUntil!);
          if (unmuteGuarded) {
            muted = false;
            if (mySeat != null && mySeat < _seats.length) {
              _seats[mySeat]['is_muted'] = false;
            }
          }
          final muteGuarded =
              _isMuted &&
              prevMuted == true &&
              muted == false &&
              _localMuteGuardUntil != null &&
              DateTime.now().isBefore(_localMuteGuardUntil!);
          if (muteGuarded) {
            muted = true;
            if (mySeat != null && mySeat < _seats.length) {
              _seats[mySeat]['is_muted'] = true;
            }
          }
          if (muted && prevMuted == false && !unmuteGuarded) {
            _localUnmuteGuardUntil = null;
            _localMuteGuardUntil = DateTime.now().add(
              const Duration(seconds: 8),
            );
          }
          _isMuted = muted;
        });
        if (_snapshotSeatHolds.length > holdsBefore) {
          _scheduleSnapshotHoldRecheck();
        }
        if (prevMy != _mySeatIndex) {
          devLog(
            '[SEAT] snapshot mySeat CHANGED $prevMy → $_mySeatIndex '
            '(recentWindow=$recentLocalSeat)',
          );
        } else {
          devLog('[SEAT] snapshot mySeat unchanged=$_mySeatIndex');
        }
        _updateAudienceList();

        if (_mySeatIndex != null) {
          final seatChanged = prevMy != _mySeatIndex;
          final muteChanged = prevMuted != _isMuted;
          if (_useOrbitVoice) {
            final inSync =
                OrbitVoiceSessionService.isConnected &&
                _orbitCanPublish &&
                _isLocalPublishing == !_isMuted;
            if (!seatChanged && inSync) {
              debugPrint('[ORBIT] snapshot heal skip — already in sync');
            } else if (!seatChanged &&
                muteChanged &&
                OrbitVoiceSessionService.isConnected &&
                _orbitCanPublish) {
              unawaited(
                _syncOrbitMicAndBilling(
                  roomId: widget.room['id'].toString(),
                  openMic: !_isMuted,
                  onSeat: true,
                ),
              );
            } else if (seatChanged ||
                muteChanged ||
                (!_isLocalPublishing && !_isMuted)) {
              _scheduleVoiceHeal(
                seatChanged
                    ? 'gateway_seat_changed'
                    : (muteChanged
                          ? 'gateway_mute_changed'
                          : 'gateway_republish'),
              );
            }
          } else if (seatChanged ||
              muteChanged ||
              (!_isLocalPublishing && !_isMuted)) {
            _scheduleVoiceHeal(
              seatChanged
                  ? 'gateway_seat_changed'
                  : (muteChanged
                        ? 'gateway_mute_changed'
                        : 'gateway_republish'),
            );
          }
        } else if (prevMy != null) {
          unawaited(
            _stopSharedAudioIfUploader(reason: 'seat_snapshot_cleared'),
          );
          unawaited(_stopLocalPublishTracked());
        }
      }
    }

    final presenceRaw = snap['presence'];
    if (presenceRaw is List) {
      final selfId = _normalizePresenceUserId(
        ref.read(userProfileProvider).value?['id'] ??
            Supabase.instance.client.auth.currentUser?.id,
      );
      // One map for the whole list: re-deduping the full list per user was
      // O(n²) on the UI thread, seconds of freeze when joining a busy room.
      final onlineById = <String, Map<String, dynamic>>{};
      for (final user in _onlineUsers) {
        final id = _normalizePresenceUserId(user['id']);
        if (id != null) onlineById[id] = user;
      }
      for (final raw in presenceRaw) {
        if (raw is! Map) continue;
        final user = Map<String, dynamic>.from(raw);
        final uid = _normalizePresenceUserId(user['id'] ?? user['user_id']);
        if (uid == null || uid == selfId) continue;
        _knownPresenceUserIds.add(uid);
        if (_presenceSnapshotBootstrap) {
          _entranceHandledUserIds.add(uid);
        }
        if (_normalizePresenceUserId(user['id']) != null) {
          onlineById[uid] = user;
        }
      }
      _onlineUsers = onlineById.values.toList();
      if (mounted) {
        setState(_updateAudienceList);
      }
    }

    _applySeatGiftTotalsSnapshot(snap['seat_gift_totals']);

    final meta = snap['meta'];
    if (meta is Map) {
      _handleRoomMetaBroadcast(Map<String, dynamic>.from(meta));
    }

    final ytSnap =
        _parseRoomJsonField(snap['youtube_state']) ??
        (meta is Map ? _parseRoomJsonField(meta['youtube_state']) : null);
    if (ytSnap != null) {
      _applyRemoteYoutubeState(ytSnap);
    }
    final audioSnap =
        _parseRoomJsonField(snap['shared_audio_state']) ??
        (meta is Map ? _parseRoomJsonField(meta['shared_audio_state']) : null);
    if (audioSnap != null) {
      _applyRemoteSharedAudioState(audioSnap);
    }
  }

  void _applySeatGiftTotalsSnapshot(dynamic raw) {
    if (raw is! Map) return;
    final next = <String, int>{};
    raw.forEach((key, value) {
      final id = key.toString();
      final n = value is num
          ? value.toInt()
          : int.tryParse(value?.toString() ?? '') ?? 0;
      if (id.isNotEmpty && n > 0) next[id] = n;
    });
    if (!mounted) return;
    _seatGiftTotals = next;
    _scheduleSeatGiftRebuild();
  }

  /// Seat gift totals change on every gift in the room; under a gift storm
  /// that was one full-screen rebuild per socket frame. Coalesce to one per
  /// rendered frame.
  void _scheduleSeatGiftRebuild() {
    if (_seatGiftRebuildScheduled || !mounted) return;
    _seatGiftRebuildScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _seatGiftRebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  bool _shouldPreserveLocalSeatOccupant(
    Map<String, dynamic> local, [
    Map<String, dynamic>? dbRow,
  ]) {
    final localUser = _normalizePresenceUserId(local['user_id']);
    if (localUser == null) return false;

    final dbUser = dbRow != null
        ? _normalizePresenceUserId(dbRow['user_id'])
        : null;

    if (RoomSeatSyncService.shouldSkipFetch(_lastSeatBroadcastAt)) {
      if (dbUser == null || dbUser == localUser) return true;
    }

    if (_remoteStreamIdsByUserId.containsKey(localUser)) {
      if (dbUser == null || dbUser == localUser) return true;
    }

    return false;
  }

  Timer? _snapshotHoldRecheckTimer;

  void _scheduleSnapshotHoldRecheck() {
    _snapshotHoldRecheckTimer?.cancel();
    _snapshotHoldRecheckTimer = Timer(
      _snapshotSeatHoldWindow + const Duration(milliseconds: 500),
      () {
        if (!mounted || _isLeavingRoom || _snapshotSeatHolds.isEmpty) return;
        unawaited(
          RoomRealtimeSocket.instance.requestSnapshot(
            widget.room['id'].toString(),
          ),
        );
      },
    );
  }

  void _scheduleDebouncedGatewaySnapshot({
    Duration debounce = const Duration(milliseconds: 800),
  }) {
    if (RoomSeatSyncService.shouldSkipFetch(_lastSeatBroadcastAt)) return;
    _gatewaySnapshotDebounceTimer?.cancel();
    _gatewaySnapshotDebounceTimer = Timer(debounce, () {
      if (!mounted) return;
      if (RoomSeatSyncService.shouldSkipFetch(_lastSeatBroadcastAt)) return;
      unawaited(
        RoomRealtimeSocket.instance.requestSnapshot(
          widget.room['id'].toString(),
        ),
      );
    });
  }

  void _scheduleReconnectBanner() {
    if (_isLeavingRoom) return;
    _reconnectBannerTimer?.cancel();
    _reconnectBannerTimer = Timer(_reconnectBannerDelay, () {
      if (!mounted || _isLeavingRoom || _roomChannelConnected) return;
      setState(() => _showReconnectBanner = true);
    });
  }

  void _cancelReconnectBanner() {
    _reconnectBannerTimer?.cancel();
    _reconnectBannerTimer = null;
    _showReconnectBanner = false;
    _roomChannelConnected = false;
  }

  Future<void> _teardownRoomChannel() async {
    if (_roomChannelTeardownDone) return;
    _roomChannelTeardownDone = true;
    _isLeavingRoom = true;
    _cancelReconnectBanner();
    _stopReconcilePoll();
    try {
      await _roomChannel.untrack().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await _roomChannel.unsubscribe().timeout(const Duration(seconds: 3));
      await Supabase.instance.client
          .removeChannel(_roomChannel)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  void _setupGlobalWinSubscription() {
    final supabase = Supabase.instance.client;
    _globalWinChannel = supabase.channel('global_win_broadcast');
    _globalWinChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'global_win_announcements',
          callback: (payload) {
            _showGlobalWinCard(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .subscribe();
  }

  void _showGlobalWinCard(Map<String, dynamic> row) {
    if (!mounted) return;
    final winId = row['id']?.toString();
    if (winId == null) return;

    final exists = _globalWinMessages.any((w) => w['id']?.toString() == winId);
    if (exists) return;
    _globalWinMessages.add({...row, 'type': 'global_win'});
    // Every lucky win in the whole app lands here (live: ~530 an hour, peaks of
    // ~1,900). Keep only the newest ones, like the room chat, so a long stay in
    // a room does not make every chat update slower (S7).
    while (_globalWinMessages.length > _maxGlobalWinMessages) {
      _globalWinMessages.removeAt(0);
    }
    _notifyChatListChanged();
    _scrollToBottom();
  }

  Future<void> _fetchRecentGlobalWins() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('global_win_announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(40);

      if (!mounted) return;
      _globalWinMessages
        ..clear()
        ..addAll(
          List<Map<String, dynamic>>.from(
            response.reversed,
          ).map((row) => {...row, 'type': 'global_win'}),
        );
      _notifyChatListChanged();
    } catch (e) {
      debugPrint('Failed to fetch global wins: $e');
    }
  }

  bool _isWinAnnouncementMessage(Map<String, dynamic> msg) {
    return msg['type'] == 'global_win' || msg['type'] == 'lucky_win';
  }

  bool _isRoomEntryNotice(Map<String, dynamic> msg) {
    if (msg['type'] != 'system') return false;
    final content = msg['content']?.toString() ?? '';
    return content.contains('Warning!') ||
        content.startsWith('Welcome to ') ||
        content.contains('entered the room');
  }

  List<Map<String, dynamic>> _buildAllTabMessages() {
    final roomMessages = _messages.where((m) {
      if (m['type'] == 'lucky_win' || m['type']?.toString() == 'mic_emoji') {
        return false;
      }
      final content = m['content']?.toString() ?? '';
      if (content.toLowerCase().contains('zego error') ||
          _zegoPrefix.hasMatch(content)) {
        return false;
      }
      return true;
    }).toList();
    final merged = <Map<String, dynamic>>[
      ...roomMessages,
      ..._globalWinMessages,
    ];

    // Same order as before (by created_at, unparseable = epoch 0), but each
    // timestamp is parsed once instead of on every comparison (S7).
    int timeOf(Map<String, dynamic> m) =>
        (DateTime.tryParse(m['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0))
            .microsecondsSinceEpoch;
    final keyed = [for (final m in merged) (time: timeOf(m), msg: m)];
    keyed.sort((a, b) => a.time.compareTo(b.time));
    return [for (final k in keyed) k.msg];
  }

  void _startActivityTimer() {
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _reportActivity();
      TaskTrackerService.trackAction('room_active_10m');
      TaskTrackerService.trackAction('newbie_room_3m');
      final bool isOnMic = _mySeatIndex != null && !_isMuted;
      if (isOnMic) {
        TaskTrackerService.trackAction('newbie_mic_3m');
      }
    });
    _reportActivity();
  }

  Future<void> _reportActivity() async {
    try {
      final supabase = Supabase.instance.client;
      final bool isOnMic = _mySeatIndex != null && !_isMuted;

      await supabase.rpc(
        'report_room_activity',
        params: {'p_room_id': widget.room['id'], 'p_is_on_mic': isOnMic},
      );

      await supabase.rpc(
        'report_user_mic_activity',
        params: {'p_is_on_mic': isOnMic},
      );

      await supabase.rpc('decay_all_rooms_hotness');
    } catch (e) {
      debugPrint('Error reporting activity: $e');
    }
  }

  Future<void> _fetchCurrentUserRole() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    if (widget.room['host_id'] == user['id']) {
      if (mounted) setState(() => _currentUserRole = 'host');
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('room_members')
          .select('role')
          .eq('room_id', widget.room['id'])
          .eq('user_id', user['id'])
          .maybeSingle();

      if (mounted && response != null) {
        setState(() => _currentUserRole = response['role'] ?? 'member');
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
    }
  }

  bool get _isRoomHost =>
      _currentUserRole == 'host' ||
      (_roomHostId != null &&
          _roomHostId == Supabase.instance.client.auth.currentUser?.id);

  bool get _canInviteRoomAdmin => _isRoomHost || _currentUserRole == 'admin';

  Future<String> _fetchRoomMemberRole(String userId) async {
    if (userId == _roomHostId) return 'host';
    try {
      final response = await Supabase.instance.client
          .from('room_members')
          .select('role')
          .eq('room_id', widget.room['id'])
          .eq('user_id', userId)
          .maybeSingle();
      return response?['role']?.toString() ?? 'member';
    } catch (e) {
      debugPrint('Error fetching member role: $e');
      return 'member';
    }
  }

  Future<void> _inviteUserAsAdmin(String userId, String username) async {
    if (!_canInviteRoomAdmin) return;
    if (userId == _roomHostId) return;

    try {
      await RoomInvitationActions.sendAdminInvitation(
        roomId: widget.room['id'].toString(),
        inviteeId: userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin invite sent to $username. They must accept.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _removeUserAsAdmin(String userId, String username) async {
    if (!_isRoomHost) return;
    if (userId == _roomHostId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          context.l10n.room_removeAdminTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          context.l10n.room_removeAdminBody,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final res = await Supabase.instance.client.rpc(
        'remove_room_sub_admin',
        params: {
          'p_room_id': widget.room['id'].toString(),
          'p_user_id': userId,
        },
      );
      final map = res is Map
          ? Map<String, dynamic>.from(res)
          : <String, dynamic>{};
      if (map['success'] != true) {
        throw Exception(map['message']?.toString() ?? 'Remove failed');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.room_removedAsAdmin(username))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  bool get _canManageRoom =>
      _currentUserRole == 'host' ||
      _currentUserRole == 'admin' ||
      _isSuperAdmin;

  bool get _canUseRoomAudio => _canManageRoom && _mySeatIndex != null;

  bool get _showRoomSpending {
    final v = _roomData?['show_spending'] ?? widget.room['show_spending'];
    if (v == null) return true;
    return v == true;
  }

  bool get _isSuperAdmin {
    return isActiveSuperBd(ref.read(myBusinessStaffProvider).asData?.value);
  }

  bool get _canSitOnLockedSeat => _isSuperAdmin;

  String get _managerLabel {
    if (_currentUserRole == 'host') return 'Host';
    if (_currentUserRole == 'admin') return 'Admin';
    if (_isSuperAdmin) return 'Super Admin';
    return 'Admin';
  }

  bool _youtubeStatesEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a['updated_at']?.toString() == b['updated_at']?.toString() &&
        a['video_id']?.toString() == b['video_id']?.toString() &&
        a['is_active'] == b['is_active'] &&
        a['status']?.toString() == b['status']?.toString() &&
        (a['timestamp'] as num?)?.toDouble() ==
            (b['timestamp'] as num?)?.toDouble();
  }

  Map<String, dynamic>? _parseRoomJsonField(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  bool _sharedAudioStatesEqual(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a['updated_at']?.toString() == b['updated_at']?.toString() &&
        a['audio_url']?.toString() == b['audio_url']?.toString() &&
        a['is_active'] == b['is_active'] &&
        a['status']?.toString() == b['status']?.toString() &&
        (a['timestamp'] as num?)?.toDouble() ==
            (b['timestamp'] as num?)?.toDouble();
  }

  void _applyRemoteSharedAudioState(Map<String, dynamic> state) {
    if (_roomData != null) {
      _roomData!['shared_audio_state'] = state;
    }
    unawaited(_sharedAudioSync.applyOnlyUpdate(state));
  }

  void _applyRemoteYoutubeState(Map<String, dynamic> state) {
    if (_roomData != null) {
      _roomData!['youtube_state'] = state;
    }
    unawaited(_youtubeSync.applyYoutubeOnlyUpdate(state));
  }

  String? get _roomHostId =>
      (_roomData?['host_id'] ?? widget.room['host_id'])?.toString();

  Future<void> _checkRoomKickBan() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final nowIso = DateTime.now().toIso8601String();
      final ban = await Supabase.instance.client
          .from('room_kicks')
          .select('id, expires_at')
          .eq('room_id', widget.room['id'])
          .eq('user_id', myId)
          .or('expires_at.is.null,expires_at.gt.$nowIso')
          .order('kicked_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (ban != null && mounted) {
        final expiresRaw = ban['expires_at']?.toString();
        final isPermanent = expiresRaw == null || expiresRaw.isEmpty;
        final message = isPermanent
            ? 'You are permanently banned from this room.'
            : 'You are banned from this room until the kick expires.';
        // Route through the same teardown a live kick uses — it stops voice,
        // clears room state and hides the bubble before popping. A bare pop()
        // left those running and the screen rendered black. Deferred to after
        // the frame so we never pop while the route is still being built.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handleKickedFromRoom(message);
        });
      }
    } catch (e) {
      debugPrint('Kick ban check error: $e');
    }
  }

  void _handleKickedFromRoom(String? reason) {
    if (_kickHandled || !mounted) return;
    _kickHandled = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason ?? 'You were removed from this room.'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
    final myId = Supabase.instance.client.auth.currentUser?.id;
    unawaited(RoomFloatingBubbleService.hideRoomBubble());
    RoomLiveScreen.cleanupRoomStatic(widget.room['id'], myId);
    clearActiveRoomState(ref);
    Navigator.of(context).pop();
  }

  bool _canKickUser(String targetUserId) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (!_canManageRoom || myId == null) return false;
    if (targetUserId == myId) return false;
    if (targetUserId == _roomHostId) return false;
    return true;
  }

  Future<bool> _isSuperAdminPeerProtected(String targetUserId) async {
    if (targetUserId.isEmpty) return false;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId != null && targetUserId == myId) return false;
    return isUserActiveSuperBd(targetUserId);
  }

  void _showSuperAdminPeerBlockedSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.room_cannotModerateSuperAdmin)),
    );
  }

  Future<bool> _hasKickingDefence(String targetUserId) async {
    final targetProfile = await Supabase.instance.client
        .from('users')
        .select('vip_level')
        .eq('id', targetUserId)
        .single();

    final int vipLevel = (targetProfile['vip_level'] as num?)?.toInt() ?? 0;
    if (vipLevel <= 0) return false;

    final vipPlan = await Supabase.instance.client
        .from('vip_plans')
        .select('has_kicking_defence')
        .eq('level', vipLevel)
        .maybeSingle();

    return vipPlan != null && vipPlan['has_kicking_defence'] == true;
  }

  Future<Duration?> _pickKickDuration(String username) async {
    return showDialog<Duration?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          context.l10n.room_addToBlacklist,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remove $username from this room. Choose how long they stay banned:',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _kickDurationOption(
              ctx,
              label: context.l10n.room_kickDuration3h,
              subtitle: context.l10n.room_kickRejoin3h,
              value: const Duration(hours: 3),
            ),
            const SizedBox(height: 8),
            _kickDurationOption(
              ctx,
              label: context.l10n.room_kickDuration24h,
              subtitle: context.l10n.room_kickRejoin24h,
              value: const Duration(days: 1),
            ),
            const SizedBox(height: 8),
            _kickDurationOption(
              ctx,
              label: context.l10n.room_kickDurationPermanent,
              subtitle: context.l10n.room_kickBannedUntilCleared,
              value: Duration.zero,
              danger: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.common_cancel),
          ),
        ],
      ),
    );
  }

  Widget _kickDurationOption(
    BuildContext ctx, {
    required String label,
    required String subtitle,
    required Duration value,
    bool danger = false,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(ctx, value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                danger ? Icons.block : Icons.timer_outlined,
                color: danger ? Colors.redAccent : const Color(0xFFFFD600),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: danger ? Colors.redAccent : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _kickUserFromRoom(String targetUserId, String username) async {
    if (!_canKickUser(targetUserId)) return;

    if (await _isSuperAdminPeerProtected(targetUserId)) {
      _showSuperAdminPeerBlockedSnack();
      return;
    }

    final selected = await _pickKickDuration(username);
    if (selected == null) return;

    final isPermanent = selected == Duration.zero;
    final expiresAt = isPermanent ? null : DateTime.now().add(selected);
    final durationLabel = isPermanent
        ? context.l10n.room_kickDurationPermanent
        : selected.inHours == 3
        ? context.l10n.room_kickDuration3h
        : context.l10n.room_kickDuration24h;

    try {
      if (await _hasKickingDefence(targetUserId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This user is protected by Kicking Defense privilege.',
              ),
            ),
          );
        }
        return;
      }

      final adminId = Supabase.instance.client.auth.currentUser!.id;
      final kickReason = 'Kicked by $_managerLabel ($durationLabel)';
      final roomId = widget.room['id'];

      await Supabase.instance.client
          .from('room_kicks')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', targetUserId);

      await Supabase.instance.client.from('room_kicks').insert({
        'room_id': roomId,
        'user_id': targetUserId,
        'admin_id': adminId,
        'reason': kickReason,
        'expires_at': expiresAt?.toIso8601String(),
      });

      unawaited(_broadcastRoomKick(userId: targetUserId, reason: kickReason));

      if (AppConstants.useRealtimeGateway) {
        try {
          await RoomRealtimeSocket.instance.seatLeave({
            'roomId': roomId.toString(),
            'user_id': targetUserId,
            'event_id': RoomLiveBroadcast.newEventId(),
          });
        } catch (e) {
          debugPrint('[ROOM] kick seatLeave via gateway: $e');
        }
      } else {
        await Supabase.instance.client
            .from('room_seats')
            .delete()
            .eq('room_id', roomId)
            .eq('user_id', targetUserId);
      }

      for (var i = 0; i < _seats.length; i++) {
        if (_seats[i]['user_id']?.toString() == targetUserId) {
          if (!AppConstants.useRealtimeGateway) {
            unawaited(
              _broadcastSeatAction(
                action: 'leave',
                seatIndex: i,
                userId: targetUserId,
              ),
            );
          }
          if (mounted) {
            setState(() {
              _seats[i]['user_id'] = null;
              _seats[i]['user'] = null;
              _seats[i]['is_muted'] = false;
            });
          }
          break;
        }
      }

      _addSystemMessage(
        '$username was kicked out of the room ($durationLabel)',
      );
    } catch (e) {
      debugPrint('Kick user error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.room_couldNotKick('$e')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _updateAudienceList() {
    final seatedUserIds = _seats
        .where((s) => s['user_id'] != null)
        .map((s) => _normalizePresenceUserId(s['user_id']))
        .whereType<String>()
        .toSet();
    final seenAudienceIds = <String>{};
    _audience = _onlineUsers.where((u) {
      final id = _normalizePresenceUserId(u['id']);
      if (id == null ||
          seatedUserIds.contains(id) ||
          seenAudienceIds.contains(id)) {
        return false;
      }
      seenAudienceIds.add(id);
      return true;
    }).toList();

    final activeAnchorIds = seatedUserIds.union(seenAudienceIds);
    _memberAnchorKeys.removeWhere((id, _) => !activeAnchorIds.contains(id));
  }

  Future<void> _openPrivateChat(
    String userId,
    String username, {
    String? avatarUrl,
  }) async {
    try {
      final conversationId = await ChatService.getOrCreateConversation(userId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            targetUserId: userId,
            targetUsername: username,
            targetAvatar: avatarUrl,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.room_couldNotOpenChat('$e')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showMemberActionsSheet({
    required String userId,
    required String username,
    String? avatarUrl,
    int? seatIndex,
  }) {
    _showUserModerationSheet(
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      seatIndex: seatIndex,
    );
  }

  bool _isUserOnSeat(String userId) {
    return _seats.any((s) => s['user_id']?.toString() == userId);
  }

  int? _findFirstAvailableSeatIndex() {
    for (var i = 0; i < _seats.length; i++) {
      if (_seats[i]['user_id'] == null && _seats[i]['is_locked'] != true) {
        return i;
      }
    }
    return null;
  }

  Future<void> _inviteUserToSeat(
    String userId, {
    int? seatIndex,
    String? username,
  }) async {
    final idx = seatIndex ?? _findFirstAvailableSeatIndex();
    if (idx == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.room_noEmptySeat),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    try {
      await RoomInvitationActions.sendSeatInvitation(
        roomId: widget.room['id'].toString(),
        inviteeId: userId,
        seatIndex: idx,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Seat invite sent to ${username ?? 'user'} (Seat ${idx + 1})',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showSeatInviteSearchSheet({int? seatIndex}) {
    final room = _roomData ?? widget.room;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          RoomSeatInviteSheet(room: room, seatIndex: seatIndex),
    );
  }

  void _showUserModerationSheet({
    required String userId,
    required String username,
    String? avatarUrl,
    int? seatIndex,
  }) {
    unawaited(
      _showUserModerationSheetAsync(
        userId: userId,
        username: username,
        avatarUrl: avatarUrl,
        seatIndex: seatIndex,
      ),
    );
  }

  Future<void> _showUserModerationSheetAsync({
    required String userId,
    required String username,
    String? avatarUrl,
    int? seatIndex,
  }) async {
    final canKick = _canKickUser(userId);
    final onSeat = seatIndex != null && _seats[seatIndex]['user_id'] == userId;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isSelf = myId != null && userId == myId;
    final peerProtected = await _isSuperAdminPeerProtected(userId);
    final isTargetHost = userId == _roomHostId;
    String targetRole = 'member';
    if (!isSelf && !isTargetHost && (_canInviteRoomAdmin || _isRoomHost)) {
      targetRole = await _fetchRoomMemberRole(userId);
    }
    if (!mounted) return;

    final showMakeAdmin =
        !isSelf &&
        !isTargetHost &&
        _canInviteRoomAdmin &&
        targetRole == 'member';
    final showRemoveAdmin =
        !isSelf && !isTargetHost && _isRoomHost && targetRole == 'admin';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _buildSeatOption(
              icon: Iconsax.message,
              title: context.l10n.room_chat,
              onTap: isSelf
                  ? null
                  : () {
                      Navigator.pop(context);
                      _openPrivateChat(userId, username, avatarUrl: avatarUrl);
                    },
              color: isSelf ? Colors.white24 : null,
            ),
            _buildSeatOption(
              icon: Iconsax.user,
              title: context.l10n.room_viewProfile,
              onTap: () {
                Navigator.pop(context);
                _showUserMiniProfile(userId, username: username);
              },
            ),
            if (_canManageRoom &&
                !isSelf &&
                !_isUserOnSeat(userId) &&
                _findFirstAvailableSeatIndex() != null)
              _buildSeatOption(
                icon: Icons.event_seat,
                title: context.l10n.room_invite,
                color: Colors.greenAccent,
                onTap: () {
                  Navigator.pop(context);
                  _inviteUserToSeat(
                    userId,
                    seatIndex: seatIndex,
                    username: username,
                  );
                },
              ),
            if (showMakeAdmin)
              _buildSeatOption(
                icon: Iconsax.shield_tick,
                title: context.l10n.room_makeAdmin,
                color: Colors.amber,
                onTap: () {
                  Navigator.pop(context);
                  _inviteUserAsAdmin(userId, username);
                },
              ),
            if (showRemoveAdmin)
              _buildSeatOption(
                icon: Iconsax.shield_cross,
                title: context.l10n.room_removeAdmin,
                color: Colors.orangeAccent,
                onTap: () {
                  Navigator.pop(context);
                  _removeUserAsAdmin(userId, username);
                },
              ),
            if (_canManageRoom &&
                !peerProtected &&
                onSeat &&
                _seats[seatIndex]['is_muted'] != true)
              _buildSeatOption(
                icon: Icons.mic_off,
                title: context.l10n.room_mute,
                onTap: () {
                  Navigator.pop(context);
                  _muteUser(seatIndex);
                },
              ),
            if (_canManageRoom && !peerProtected && !isSelf && onSeat)
              _buildSeatOption(
                icon: Icons.event_seat_outlined,
                title: context.l10n.room_removeFromSeat,
                color: Colors.orangeAccent,
                onTap: () {
                  Navigator.pop(context);
                  _removeUserFromSeat(seatIndex);
                },
              ),
            if (canKick && !peerProtected)
              _buildSeatOption(
                icon: Icons.block,
                title: context.l10n.room_addToBlacklist,
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  _kickUserFromRoom(userId, username);
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _withResolvedTulasiIcons(
    List<Map<String, dynamic>> games,
  ) {
    return games.map((g) {
      final cfg = g['config_data'] is Map
          ? Map<String, dynamic>.from(g['config_data'] as Map)
          : null;
      final isTulasi =
          cfg?['provider']?.toString() == 'tulasi' ||
          isTulasiGameUrl(g['game_url']?.toString() ?? '');
      if (!isTulasi) return g;
      final icon = resolveTulasiIconUrl(
        iconUrl: g['icon_url']?.toString(),
        configData: cfg,
      );
      if (icon.isEmpty) return g;
      return {...g, 'icon_url': icon};
    }).toList();
  }

  // Opening the games sheet refetches the catalog. Publishing an identical list
  // still rebuilt the whole sheet — re-laying out every grid and re-measuring
  // every tile label — which is what made the open sheet feel stuck. Only a
  // real change is worth a rebuild.
  String _gamesSignature(List<Map<String, dynamic>> list) {
    final b = StringBuffer()..write(list.length);
    for (final g in list) {
      b
        ..write('|')
        ..write(g['id'] ?? g['slug'] ?? '')
        ..write(':')
        ..write(g['icon_url'] ?? '')
        ..write(':')
        ..write(g['maintenance_mode'] ?? '');
    }
    return b.toString();
  }

  String _publishedGamesSignature = '';

  void _publishActiveGames(List<Map<String, dynamic>> next) {
    if (!mounted) return;
    final signature = _gamesSignature(next);
    _activeGames = next;
    if (signature == _publishedGamesSignature) return;
    _publishedGamesSignature = signature;
    _gamesRev.value++;
  }

  DateTime? _lastGamesCatalogFetch;
  static const Duration _gamesCatalogTtl = Duration(seconds: 90);

  Future<void> _fetchActiveGames({bool force = false}) async {
    final lastFetch = _lastGamesCatalogFetch;
    if (!force &&
        lastFetch != null &&
        _activeGames.isNotEmpty &&
        DateTime.now().difference(lastFetch) < _gamesCatalogTtl) {
      return;
    }
    _lastGamesCatalogFetch = DateTime.now();
    try {
      final cached = HiveCacheService.loadGames();
      if (cached != null && cached.isNotEmpty && mounted) {
        final visibleCached = await filterGamesByAudience(
          _withResolvedTulasiIcons(cached),
        );
        _publishActiveGames(visibleCached);
      }

      final catsById = <String, Map<String, dynamic>>{};
      try {
        final catsRes = await Supabase.instance.client
            .from('room_game_categories')
            .select('id, name, sort_order')
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        for (final row in List<Map<String, dynamic>>.from(catsRes as List)) {
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          catsById[id] = row;
        }
      } catch (e) {
        debugPrint('[GAMES] categories load failed: $e');
      }

      final response = await Supabase.instance.client
          .from('game_configs')
          .select(
            'id, slug, name, icon_url, game_url, sort_order, maintenance_mode, maintenance_message, webview_height_percent, config_data, category_id',
          )
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final games = List<Map<String, dynamic>>.from(response)
          .where((g) {
            final catId = g['category_id']?.toString();
            if (catId == null || catId.isEmpty) return true;
            return catsById.containsKey(catId);
          })
          .map((g) {
            final catId = g['category_id']?.toString();
            final cat = catId != null ? catsById[catId] : null;
            final cfg = g['config_data'] is Map
                ? Map<String, dynamic>.from(g['config_data'] as Map)
                : null;
            final isTulasi =
                cfg?['provider']?.toString() == 'tulasi' ||
                isTulasiGameUrl(g['game_url']?.toString() ?? '');
            final rawIcon = g['icon_url']?.toString() ?? '';
            final icon = isTulasi
                ? resolveTulasiIconUrl(iconUrl: rawIcon, configData: cfg)
                : rawIcon;
            return {
              ...g,
              'icon_url': icon.isNotEmpty ? icon : rawIcon,
              'display_name': g['name'],
              'category_id': catId,
              'category_name':
                  cat?['name']?.toString() ??
                  (isTulasi ? 'More Games' : 'Livo Games'),
              'category_sort': cat?['sort_order'] ?? (isTulasi ? 100 : 20),
            };
          })
          .toList();
      try {
        games.addAll(await fetchWaveRoomGames());
      } catch (e) {
        debugPrint('[GAMES] wave catalog failed: $e');
      }
      debugPrint('[GAMES] fetched active=${games.length}');
      await HiveCacheService.saveGames(games);
      final visible = await filterGamesByAudience(games);
      debugPrint('[GAMES] visible after audience=${visible.length}');

      _publishActiveGames(visible);
    } catch (e) {
      debugPrint('Error fetching active games: $e');
      // A failed refresh must not poison the TTL, or the next open would also
      // skip the retry and the sheet would stay on whatever it had.
      _lastGamesCatalogFetch = null;
      final cached = HiveCacheService.loadGames();
      if (cached != null && cached.isNotEmpty && mounted) {
        final visibleCached = await filterGamesByAudience(
          _withResolvedTulasiIcons(cached),
        );
        _publishActiveGames(visibleCached);
      }
    }
  }

  Future<void> _initOrbitVoice({required bool openMic}) {
    _orbitInitDesiredMic = openMic;
    final run = _orbitInitChain.then(
      (_) => _initOrbitVoiceUnlocked(openMic: _orbitInitDesiredMic ?? openMic),
    );
    _orbitInitChain = run.catchError((_) {});
    return run;
  }

  Future<bool> _remintOrbitPublishToken({
    required String roomId,
    required bool onSeat,
  }) async {
    final session = await OrbitVoiceSessionService.fetchSession(
      roomId: roomId,
      openMic: true,
      onSeat: onSeat,
    );
    _noteOrbitBilling(true);
    if (session == null || session['error'] != null) {
      debugPrint('[ORBIT] remint failed: $session');
      return false;
    }
    final token = session['token']?.toString() ?? '';
    final url = session['livekit_url']?.toString() ?? '';
    if (token.isEmpty || url.isEmpty) return false;
    final livekitRoom = session['livekit_room']?.toString();
    if (livekitRoom != null && livekitRoom.isNotEmpty) {
      _zegoRoomId = livekitRoom;
      RoomVoiceSessionService.markLoggedIn(livekitRoom);
    }

    final ok = await OrbitVoiceSessionService.connect(
      livekitUrl: url,
      token: token,
      forceReconnect: true,
      skLiveRoomId: roomId,
      canPublish: session['can_publish'] == true,
    );
    if (!ok) return false;

    _orbitCanPublish = session['can_publish'] == true;
    await OrbitVoiceSessionService.waitForPublishPermission();
    _orbitCanPublish =
        _orbitCanPublish || OrbitVoiceSessionService.canPublishNow;
    return OrbitVoiceSessionService.canPublishNow || _orbitCanPublish;
  }

  Future<bool> _regrantOrbitPublishInPlace({
    required String roomId,
    required bool onSeat,
  }) async {
    if (!OrbitVoiceSessionService.isConnected) return false;
    final sw = Stopwatch()..start();
    final res = await OrbitVoiceSessionService.fetchSession(
      roomId: roomId,
      openMic: true,
      onSeat: onSeat,
      billingOnly: true,
    );
    _noteOrbitBilling(true);
    if (res == null || res['error'] != null || res['join_ok'] == false) {
      debugPrint('[ORBIT] regrant in place rejected: $res');
      return false;
    }
    final granted = await OrbitVoiceSessionService.waitForPublishPermission(
      timeout: const Duration(milliseconds: 1200),
    );
    debugPrint(
      '[ORBIT] regrant in place granted=$granted in ${sw.elapsedMilliseconds}ms',
    );
    return granted;
  }

  Future<bool> _ensureOrbitPublishGrant({
    required String roomId,
    required bool onSeat,
  }) async {
    if (await _regrantOrbitPublishInPlace(roomId: roomId, onSeat: onSeat)) {
      return true;
    }
    return _remintOrbitPublishToken(roomId: roomId, onSeat: onSeat);
  }

  Future<void> _syncOrbitMicAndBilling({
    required String roomId,
    required bool openMic,
    required bool onSeat,
  }) {
    final gen = ++_orbitMicIntentGen;
    final run = _orbitMicChain.then(
      (_) => _syncOrbitMicAndBillingUnlocked(
        roomId: roomId,
        openMic: openMic,
        onSeat: onSeat,
        gen: gen,
      ),
    );
    _orbitMicChain = run.catchError((_) {});
    return run;
  }

  bool _orbitBillingRecentlySent(bool openMic) {
    final at = _orbitLastBillingAt;
    if (at == null || _orbitLastBillingOpenMic != openMic) return false;
    return DateTime.now().difference(at) < const Duration(milliseconds: 1200);
  }

  void _noteOrbitBilling(bool openMic) {
    _orbitLastBillingAt = DateTime.now();
    _orbitLastBillingOpenMic = openMic;
  }

  Future<bool> _ensureOrbitPublishSession({
    required String roomId,
    required bool onSeat,
    required bool openMic,
    bool forceReconnectAlways = false,
  }) async {
    if (!forceReconnectAlways &&
        OrbitVoiceSessionService.isConnected &&
        _orbitCanPublish &&
        OrbitVoiceSessionService.canPublishNow) {
      debugPrint('[ORBIT] publish session skip — already on publish JWT');
      return true;
    }

    final session = await OrbitVoiceSessionService.fetchSessionCached(
      roomId: roomId,
      openMic: openMic,
      onSeat: onSeat,
    );
    if (session == null || session['error'] != null) {
      debugPrint('[ORBIT] publish session failed: $session');
      return false;
    }
    _noteOrbitBilling(openMic);
    final canPublish = session['can_publish'] == true;
    final token = session['token']?.toString() ?? '';
    final url = session['livekit_url']?.toString() ?? '';
    final livekitRoom = session['livekit_room']?.toString();
    if (livekitRoom != null && livekitRoom.isNotEmpty) {
      _zegoRoomId = livekitRoom;
      RoomVoiceSessionService.markLoggedIn(livekitRoom);
    }

    if (openMic && !canPublish) {
      _orbitCanPublish = false;
      debugPrint('[ORBIT] openMic requested but can_publish=false');
      return false;
    }

    final wasConnected = OrbitVoiceSessionService.isConnected;
    var livePublish = OrbitVoiceSessionService.canPublishNow;
    if (wasConnected && canPublish && !livePublish) {
      livePublish = await OrbitVoiceSessionService.waitForPublishPermission(
        timeout: const Duration(milliseconds: 700),
      );
    }
    final needReconnect =
        forceReconnectAlways ||
        !wasConnected ||
        (canPublish && !livePublish && token.isNotEmpty && url.isNotEmpty);
    if (wasConnected && !needReconnect && canPublish && !openMic) {
      debugPrint('[ORBIT] publish granted in place — no reconnect');
      await OrbitVoiceSessionService.primeMicIfNeeded();
    }

    if (needReconnect) {
      if (token.isEmpty || url.isEmpty) {
        if (wasConnected && !forceReconnectAlways) {
          debugPrint(
            '[ORBIT] publish wait failed — keeping connection (no token swap)',
          );
          _orbitCanPublish = OrbitVoiceSessionService.canPublishNow;
          return _orbitCanPublish;
        }
        debugPrint('[ORBIT] publish session missing token/url');
        return false;
      }
      final ok = await OrbitVoiceSessionService.connect(
        livekitUrl: url,
        token: token,
        forceReconnect: wasConnected,
        skLiveRoomId: roomId,
        canPublish: canPublish,
      );
      if (!ok) {
        debugPrint('[ORBIT] publish reconnect failed');
        return false;
      }
      debugPrint(
        '[ORBIT] publish JWT connected canPublish=$canPublish '
        'forceReconnect=$wasConnected',
      );
    } else {
      debugPrint(
        '[ORBIT] publish session ok reuse connection canPublish=$canPublish',
      );
    }
    _orbitCanPublish = canPublish || OrbitVoiceSessionService.canPublishNow;
    return true;
  }

  Future<void> _syncOrbitMicAndBillingUnlocked({
    required String roomId,
    required bool openMic,
    required bool onSeat,
    required int gen,
  }) async {
    if (gen != _orbitMicIntentGen) {
      debugPrint(
        '[ORBIT] mic sync skipped stale gen=$gen latest=$_orbitMicIntentGen '
        'wantedOpen=$openMic',
      );
      return;
    }
    OrbitVoiceSessionService.setMicIntent(openMic);

    if (openMic) {
      if (_isMuted) {
        debugPrint('[ORBIT] mic sync skip open — locally muted');
        return;
      }

      if (!OrbitVoiceSessionService.isConnected) {
        debugPrint('[ORBIT] mic sync open — transport dead, reminting');
        await _initOrbitVoice(openMic: true);
        return;
      }

      if (!OrbitVoiceSessionService.canPublishNow) {
        final granted = await _ensureOrbitPublishGrant(
          roomId: roomId,
          onSeat: onSeat,
        );
        if (!granted || gen != _orbitMicIntentGen || _isMuted) {
          await OrbitVoiceSessionService.setMicEnabled(false);
          _isLocalPublishing = false;
          debugPrint('[ORBIT] mic sync rolled back open (regrant/muted/stale)');
          return;
        }
      }

      var ok = await OrbitVoiceSessionService.setMicEnabled(true);
      if (gen != _orbitMicIntentGen || _isMuted) {
        await OrbitVoiceSessionService.setMicEnabled(false);
        _isLocalPublishing = false;
        debugPrint('[ORBIT] mic sync rolled back open (muted/stale)');
        return;
      }

      if (!ok && !OrbitVoiceSessionService.lastMicFailWasPermission) {
        for (var i = 1; i <= 2 && !ok; i++) {
          await Future<void>.delayed(Duration(milliseconds: 200 * i));
          if (gen != _orbitMicIntentGen || _isMuted) {
            await OrbitVoiceSessionService.setMicEnabled(false);
            _isLocalPublishing = false;
            return;
          }
          ok = await OrbitVoiceSessionService.setMicEnabled(true);
        }
      }
      if (!ok) {
        debugPrint('[ORBIT] mic publish failed — regrant publish');
        final regranted = await _ensureOrbitPublishGrant(
          roomId: roomId,
          onSeat: onSeat,
        );
        if (gen != _orbitMicIntentGen || _isMuted) {
          await OrbitVoiceSessionService.setMicEnabled(false);
          _isLocalPublishing = false;
          return;
        }
        if (regranted) {
          ok = await OrbitVoiceSessionService.setMicEnabled(true);
        }
      }

      _orbitCanPublish =
          _orbitCanPublish || OrbitVoiceSessionService.canPublishNow;
      _isLocalPublishing = ok;
      if (!ok) {
        debugPrint(
          '[ORBIT] mic publish failed after publish JWT — mute rollback',
        );
        await _rollbackOrbitMicFailed(roomId: roomId, reason: 'sync_publish');
      } else if (!_orbitBillingRecentlySent(true)) {
        _noteOrbitBilling(true);
        unawaited(
          OrbitVoiceSessionService.fetchSession(
            roomId: roomId,
            openMic: true,
            onSeat: onSeat,
            billingOnly: true,
          ),
        );
      }
    } else {
      await OrbitVoiceSessionService.setMicEnabled(false);
      _isLocalPublishing = false;
      if (gen == _orbitMicIntentGen && !_orbitBillingRecentlySent(false)) {
        _noteOrbitBilling(false);
        unawaited(
          OrbitVoiceSessionService.fetchSession(
            roomId: roomId,
            openMic: false,
            onSeat: onSeat,
            billingOnly: true,
          ),
        );
      }
    }
    _zegoLoginReady = true;
  }

  Future<void> _initOrbitVoiceUnlocked({required bool openMic}) async {
    final roomId = widget.room['id']?.toString() ?? '';
    if (roomId.isEmpty) return;
    final onSeat = _mySeatIndex != null;
    final wantPublish = onSeat || openMic;
    OrbitVoiceSessionService.setMicIntent(openMic);
    debugPrint('[ORBIT] init openMic=$openMic onSeat=$onSeat room=$roomId');
    try {
      final liveHere = OrbitVoiceSessionService.isLiveForRoom(roomId);
      if (liveHere) {
        OrbitVoiceSessionService.claimPrefetch(roomId);
      }
      final startedAsListenerOnly =
          liveHere &&
          !_orbitCanPublish &&
          !OrbitVoiceSessionService.canPublishNow;
      final canReuse =
          liveHere &&
          (_orbitCanPublish || !wantPublish) &&
          !startedAsListenerOnly;
      if (canReuse) {
        unawaited(OrbitVoiceSessionService.reassertRemoteHearing('reuse'));
        unawaited(
          OrbitVoiceSessionService.setRemoteAudioMuted(_roomAudioMuted),
        );
        unawaited(
          OrbitVoiceSessionService.applyRoomTopicAudioMode(
            (_roomData ?? widget.room)['room_topic']?.toString(),
          ),
        );
        unawaited(
          _syncOrbitMicAndBilling(
            roomId: roomId,
            openMic: openMic,
            onSeat: onSeat,
          ),
        );
        debugPrint(
          '[ORBIT] reuse connection publishing=$_isLocalPublishing '
          'canPublish=$_orbitCanPublish',
        );
        return;
      }

      var session = await OrbitVoiceSessionService.fetchSessionCached(
        roomId: roomId,
        openMic: openMic,
        onSeat: onSeat,
      );
      if (session == null || session['error'] != null) {
        debugPrint('[ORBIT] session failed (try fresh): $session');
        session = await OrbitVoiceSessionService.fetchSession(
          roomId: roomId,
          openMic: openMic,
          onSeat: onSeat,
        );
      }
      if (session == null || session['error'] != null) {
        debugPrint('[ORBIT] session failed: $session');
        _zegoLoginReady = false;
        return;
      }
      final token = session['token']?.toString() ?? '';
      final url = session['livekit_url']?.toString() ?? '';
      if (token.isEmpty || url.isEmpty) {
        debugPrint('[ORBIT] missing token/url');
        _zegoLoginReady = false;
        return;
      }

      final canPublish = session['can_publish'] == true;
      final wasConnected = OrbitVoiceSessionService.isConnected && liveHere;
      var livePublish = OrbitVoiceSessionService.canPublishNow;
      if (wasConnected &&
          wantPublish &&
          canPublish &&
          !livePublish &&
          !startedAsListenerOnly) {
        livePublish = await OrbitVoiceSessionService.waitForPublishPermission(
          timeout: const Duration(milliseconds: 700),
        );
      }
      final forceReconnect =
          wasConnected && wantPublish && canPublish && !livePublish;
      if (wasConnected &&
          wantPublish &&
          canPublish &&
          livePublish &&
          !openMic) {
        debugPrint('[ORBIT] init publish granted in place — no reconnect');
        await OrbitVoiceSessionService.primeMicIfNeeded();
      }
      final ok = await OrbitVoiceSessionService.connect(
        livekitUrl: url,
        token: token,
        forceReconnect: forceReconnect,
        skLiveRoomId: roomId,
        canPublish: canPublish,
      );
      var connected = ok;
      if (!connected) {
        debugPrint('[ORBIT] connect failed — one retry');
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        final retry = await OrbitVoiceSessionService.fetchSession(
          roomId: roomId,
          openMic: openMic,
          onSeat: onSeat,
        );
        final retryToken = retry?['token']?.toString() ?? '';
        final retryUrl = retry?['livekit_url']?.toString() ?? '';
        if (retryToken.isNotEmpty && retryUrl.isNotEmpty) {
          connected = await OrbitVoiceSessionService.connect(
            livekitUrl: retryUrl,
            token: retryToken,
            forceReconnect: true,
            skLiveRoomId: roomId,
            canPublish: retry?['can_publish'] == true,
          );
        }
      }
      if (!connected) {
        _zegoLoginReady = false;
        return;
      }

      _orbitCanPublish = canPublish || OrbitVoiceSessionService.canPublishNow;
      _zegoLoginReady = true;
      _zegoRoomId = session['livekit_room']?.toString() ?? roomId;
      RoomVoiceSessionService.markLoggedIn(_zegoRoomId!);
      _noteOrbitBilling(openMic);

      unawaited(
        OrbitVoiceSessionService.applyRoomTopicAudioMode(
          (_roomData ?? widget.room)['room_topic']?.toString(),
        ),
      );

      unawaited(OrbitVoiceSessionService.reassertRemoteHearing('init'));
      unawaited(OrbitVoiceSessionService.setRemoteAudioMuted(_roomAudioMuted));

      var desiredMic = _orbitInitDesiredMic ?? openMic;
      if (desiredMic && _isMuted) {
        desiredMic = false;
      }
      if (desiredMic) {
        var micOk = await OrbitVoiceSessionService.setMicEnabled(true);
        if (!micOk &&
            !_isMuted &&
            !OrbitVoiceSessionService.lastMicFailWasPermission) {
          for (var i = 1; i <= 2 && !micOk; i++) {
            await Future<void>.delayed(Duration(milliseconds: 200 * i));
            if (_isMuted) break;
            micOk = await OrbitVoiceSessionService.setMicEnabled(true);
          }
        }
        if (!micOk && !_isMuted) {
          debugPrint('[ORBIT] init mic failed — one reconnect+retry');
          final ensured = await _ensureOrbitPublishSession(
            roomId: roomId,
            onSeat: onSeat,
            openMic: true,
            forceReconnectAlways: true,
          );
          if (ensured && !_isMuted) {
            micOk = await OrbitVoiceSessionService.setMicEnabled(true);
          }
        }
        _isLocalPublishing = micOk && !_isMuted;
        if (!micOk) {
          debugPrint('[ORBIT] init mic publish failed — mute rollback');
          await _rollbackOrbitMicFailed(roomId: roomId, reason: 'init_publish');
        }
      } else {
        unawaited(OrbitVoiceSessionService.setMicEnabled(false));
        _isLocalPublishing = false;
      }
      debugPrint(
        '[ORBIT] loginReady=true publishing=$_isLocalPublishing '
        'canPublish=$_orbitCanPublish forceReconnect=$forceReconnect',
      );
    } catch (e) {
      debugPrint('[ORBIT] init error: $e');
      _zegoLoginReady = false;
      _orbitCanPublish = false;
    }
  }

  Future<void> _rollbackOrbitMicFailed({
    required String roomId,
    required String reason,
  }) async {
    _isLocalPublishing = false;
    _isMuted = true;
    RoomFloatingBubbleService.micMuted = true;
    _localUnmuteGuardUntil = null;
    _localMuteGuardUntil = DateTime.now().add(const Duration(seconds: 8));
    final seat = _mySeatIndex;
    if (seat != null && seat < _seats.length) {
      _seats[seat]['is_muted'] = true;
    }
    if (mounted) setState(() {});
    try {
      await OrbitVoiceSessionService.setMicEnabled(false);
    } catch (_) {}
    try {
      await OrbitVoiceSessionService.fetchSession(
        roomId: roomId,
        openMic: false,
        onSeat: seat != null,
        billingOnly: true,
      );
    } catch (e) {
      debugPrint('[ORBIT] mute billing rollback ($reason): $e');
    }
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (seat != null && myId != null) {
      unawaited(
        _broadcastSeatAction(
          action: 'mute',
          seatIndex: seat,
          userId: myId,
          isMuted: true,
        ),
      );
    }
    _addSystemMessage('Microphone could not start. You are muted on the seat.');
  }

  void _restoreMinimizedVoiceState() {
    final seat = RoomMinimizedKeepAlive.voiceSeatIndex;
    final muted = RoomMinimizedKeepAlive.voiceMuted;
    final canPub = RoomMinimizedKeepAlive.voiceOrbitCanPublish;
    final publishing = RoomMinimizedKeepAlive.voiceLocalPublishing;
    if (seat != null) _mySeatIndex = seat;
    if (muted != null) _isMuted = muted;
    if (canPub != null) _orbitCanPublish = canPub;
    if (publishing != null) _isLocalPublishing = publishing;
    if (OrbitVoiceSessionService.isConnected && _mySeatIndex != null) {
      _orbitCanPublish = true;
      _zegoLoginReady = true;
    }
    if (_mySeatIndex != null && _mySeatIndex! < _seats.length) {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      _seats[_mySeatIndex!]['user_id'] =
          myId ?? _seats[_mySeatIndex!]['user_id'];
      _seats[_mySeatIndex!]['is_muted'] = _isMuted;
    }
    debugPrint(
      '[ORBIT] restore minimize seat=$_mySeatIndex muted=$_isMuted '
      'canPub=$_orbitCanPublish pub=$_isLocalPublishing '
      'lk=${OrbitVoiceSessionService.isConnected}',
    );
  }

  Future<void> _initZego() async {
    _voiceBackend = VoiceBackend.orbit;
    unawaited(
      ref
          .read(voiceBackendConfigProvider.future)
          .then((cfg) {
            debugPrint('[VOICE] backend=orbit (cfg=${cfg.backend.name})');
          })
          .catchError((Object e) {
            debugPrint('[VOICE] backend cfg skipped: $e');
          }),
    );
    Map<String, dynamic>? user = ref.read(userProfileProvider).value;
    if (user == null) {
      try {
        user = await ref.read(userProfileProvider.future);
      } catch (e) {
        debugPrint('[ZEGO_INIT] profile load failed: $e');
        return;
      }
    }
    if (!mounted || user == null) return;

    if (_useOrbitVoice) {
      RoomMinimizedKeepAlive.relinquishOrbitHeal();
      OrbitVoiceSessionService.setTransportLostHandler((reason) {
        if (!mounted) return;
        _isLocalPublishing = false;
        if (_mySeatIndex != null) {
          _scheduleVoiceHeal('orbit_$reason');
        } else {
          _scheduleOrbitHearingHeal('orbit_$reason');
        }
      });
      OrbitVoiceSessionService.setSpeakerLevelsHandler(
        _applyOrbitSpeakerLevels,
      );
      if (_resumingMinimizedSession && OrbitVoiceSessionService.isConnected) {
        debugPrint(
          '[ORBIT] resume minimize seat=$_mySeatIndex muted=$_isMuted '
          'canPub=$_orbitCanPublish',
        );
        _zegoLoginReady = true;
        if (_orbitCanPublish || _mySeatIndex != null) {
          _orbitCanPublish = true;
        }
        unawaited(
          OrbitVoiceSessionService.reassertRemoteHearing('minimize_resume'),
        );
        unawaited(
          OrbitVoiceSessionService.setRemoteAudioMuted(_roomAudioMuted),
        );
        await _syncOrbitMicAndBilling(
          roomId: widget.room['id'].toString(),
          openMic: !_isMuted && _mySeatIndex != null,
          onSeat: _mySeatIndex != null,
        );
        if (_mySeatIndex != null) {
          _scheduleVoiceHeal('minimize_resume');
        } else {
          _scheduleOrbitHearingHeal('minimize_resume');
        }
        return;
      }
      if (_resumingMinimizedSession && !OrbitVoiceSessionService.isConnected) {
        debugPrint('[ORBIT] resume minimize — transport dead, full init');
      }
      await _initOrbitVoice(openMic: !_isMuted && _mySeatIndex != null);
      return;
    }

    await _initOrbitVoice(openMic: !_isMuted && _mySeatIndex != null);
  }

  void _applyOrbitSpeakerLevels(Map<String, double> levels) {
    if (!mounted || !context.mounted || levels.isEmpty) return;
    var changed = false;
    levels.forEach((identity, level) {
      final userId = _userIdForOrbitIdentity(identity);
      if (userId == null || userId.isEmpty) return;
      if (_mergeSoundLevel(userId, level)) changed = true;
    });
    if (changed) _bumpSoundLevels();
  }

  /// LiveKit reports active speakers several times a second, and every seat
  /// listens to this one notifier — so a ten-speaker room used to rebuild all
  /// ten seats ten times a second. The first report lands immediately; the rest
  /// are coalesced into one rebuild per window, and the timer stops as soon as
  /// the reports do.
  void _bumpSoundLevels() {
    if (_soundLevelsDisposed) return;
    if (_soundLevelsCooldown != null) {
      _soundLevelsPending = true;
      return;
    }
    _soundLevelsVersion.value++;
    _startSoundLevelCooldown();
  }

  void _startSoundLevelCooldown() {
    _soundLevelsCooldown = Timer(_soundLevelsFlushInterval, () {
      _soundLevelsCooldown = null;
      if (_soundLevelsDisposed || !_soundLevelsPending) return;
      _soundLevelsPending = false;
      _soundLevelsVersion.value++;
      _startSoundLevelCooldown();
    });
  }

  String? _userIdForOrbitIdentity(String identity) {
    final id = identity.trim();
    if (id.isEmpty) return null;
    final cached = _orbitIdentityUserIds[id];
    if (cached != null) return cached;

    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId != null && _orbitIdsMatch(id, myId)) {
      return _rememberOrbitIdentity(id, myId);
    }
    for (final seat in _seats) {
      final seatUserId = seat['user_id']?.toString();
      if (seatUserId == null || seatUserId.isEmpty) continue;
      if (_orbitIdsMatch(id, seatUserId)) {
        return _rememberOrbitIdentity(id, seatUserId);
      }
    }
    // No seat claims this identity yet. Not cached: a seat may still appear,
    // and caching the fallback would pin the wrong answer for the session.
    return id;
  }

  String _rememberOrbitIdentity(String identity, String userId) {
    if (_orbitIdentityUserIds.length >= _orbitIdentityCacheMax) {
      _orbitIdentityUserIds.remove(_orbitIdentityUserIds.keys.first);
    }
    _orbitIdentityUserIds[identity] = userId;
    return userId;
  }

  bool _orbitIdsMatch(String identity, String userId) {
    final a = identity.toLowerCase();
    final b = userId.toLowerCase();
    if (a == b) return true;
    return a.endsWith('_$b') || a.endsWith(':$b');
  }

  bool _isSeatSpeaking(String userId) {
    if (userId.isEmpty) return false;
    if (_hasSharedAudioSeatPulse(userId)) return true;
    if (_speakSticky[userId] == true) return true;
    return (_soundLevels[userId] ?? 0) >= _speakOnThreshold;
  }

  double _seatSoundLevelForUser(String userId) {
    if (_hasSharedAudioSeatPulse(userId)) {
      return _SeatSoundWaves.loudThreshold + 12;
    }
    return _soundLevels[userId] ?? 0;
  }

  bool _hasSharedAudioSeatPulse(String userId) {
    final dj = _sharedAudioSeatPulseUserId;
    if (dj == null || dj.isEmpty || userId.isEmpty) return false;
    if (dj == userId) return true;
    final a = _normalizePresenceUserId(dj);
    final b = _normalizePresenceUserId(userId);
    if (a != null && b != null && a == b) return true;
    return _orbitIdsMatch(dj, userId);
  }

  void _attachSharedAudioSeatPulseListener() {
    if (_sharedAudioSeatPulseListening) return;
    _sharedAudioSeatPulseListening = true;
    _sharedAudioSync.session.addListener(_syncSharedAudioSeatPulse);
    _syncSharedAudioSeatPulse();
  }

  void _detachSharedAudioSeatPulseListener() {
    if (!_sharedAudioSeatPulseListening) return;
    _sharedAudioSeatPulseListening = false;
    try {
      _sharedAudioSync.session.removeListener(_syncSharedAudioSeatPulse);
    } catch (_) {}
  }

  Future<void> _stopSharedAudioIfUploader({required String reason}) async {
    try {
      if (!_sharedAudioSync.isUploader) return;
      if (_sharedAudioSync.session.value?.isActive != true) return;
      _sharedAudioQueue.cancelAutoAdvance();
      await _sharedAudioSync.stopAudio(reason: reason, force: true);
    } catch (e) {
      debugPrint('[RoomSharedAudio] stop on $reason failed: $e');
    }
  }

  void _syncSharedAudioSeatPulse() {
    if (!mounted) return;
    final session = _sharedAudioSync.session.value;
    final nextRaw = (session != null && session.isPlaying)
        ? session.startedBy?.trim()
        : null;
    final next = nextRaw == null || nextRaw.isEmpty
        ? null
        : (_normalizePresenceUserId(nextRaw) ?? nextRaw);

    if (next == _sharedAudioSeatPulseUserId) return;

    final prev = _sharedAudioSeatPulseUserId;
    _sharedAudioSeatPulseUserId = next;

    if (prev != null && prev.isNotEmpty && (next == null || next != prev)) {
      _speakHoldTimers[prev]?.cancel();
      _speakHoldTimers.remove(prev);
      _soundLevels.remove(prev);
      _speakSticky[prev] = false;
    }

    if (next != null && next.isNotEmpty) {
      _speakHoldTimers[next]?.cancel();
      _speakHoldTimers.remove(next);
      _soundLevels[next] = _SeatSoundWaves.loudThreshold + 12;
      _speakSticky[next] = true;
    }

    if (!_soundLevelsDisposed) _soundLevelsVersion.value++;
    setState(() {});
  }

  bool _mergeSoundLevel(String userId, double level) {
    final prev = _soundLevels[userId] ?? 0;
    final prevSticky = _speakSticky[userId] == true;
    final prevActive = prevSticky || prev >= _speakOnThreshold;
    _soundLevels[userId] = level;
    var changed = false;

    if (level >= _speakOnThreshold) {
      _speakHoldTimers[userId]?.cancel();
      _speakHoldTimers.remove(userId);
      if (!prevSticky) {
        _speakSticky[userId] = true;
        changed = true;
      }
    } else if (level < _speakOffThreshold && prevSticky) {
      if (!_speakHoldTimers.containsKey(userId)) {
        _speakHoldTimers[userId] = Timer(_speakHoldDuration, () {
          _speakHoldTimers.remove(userId);
          if (!mounted) return;
          final current = _soundLevels[userId] ?? 0;
          if (current < _speakOffThreshold) {
            _speakSticky[userId] = false;
            _bumpSoundLevels();
          }
        });
      }
    }

    final nextActive =
        _speakSticky[userId] == true || level >= _speakOnThreshold;
    final prevLoud = prev >= _SeatSoundWaves.loudThreshold;
    final nextLoud = level >= _SeatSoundWaves.loudThreshold;
    if (prevActive != nextActive) changed = true;
    if (prevLoud != nextLoud) changed = true;
    if (nextActive && (level - prev).abs() >= 8) changed = true;
    return changed;
  }

  void _initSeats({String source = 'unknown'}) {
    final micCount = (_roomData?['mic_count'] ?? widget.room['mic_count']) ?? 8;
    if (source == 'room_meta_broadcast' &&
        _seats.length == micCount &&
        _seats.isNotEmpty) {
      devLog('[SEAT] initSeats SKIP same micCount=$micCount ($source)');
      return;
    }

    devLog('INITIALIZING_SEATS_WITH_COUNT: $micCount ($source)');
    final previous = _seats
        .map((s) => Map<String, dynamic>.from(s))
        .toList(growable: false);

    _seats = List.generate(micCount, (index) {
      if (index < previous.length) {
        final preserved = Map<String, dynamic>.from(previous[index]);
        preserved['index'] = index;
        return preserved;
      }
      return {
        'index': index,
        'user_id': null,
        'user': null,
        'is_muted': false,
        'is_locked': false,
      };
    });
    if (_mySeatIndex != null && _mySeatIndex! >= micCount) {
      devLog('[SEAT] initSeats mySeat $_mySeatIndex out of range → null');
      _mySeatIndex = null;
    }
    if (RoomSeatSyncService.shouldSkipFetch(_lastSeatBroadcastAt)) {
      devLog('[SEAT] initSeats skip fetchSeats (recent claim window)');
      return;
    }
    _fetchSeats();
  }

  Future<void> _clearStaleSeatOnFreshEntry() async {
    final clearGeneration = _seatSessionGeneration;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final roomId = widget.room['id'].toString();
    devLog(
      '[SEAT] clearStale start gen=$clearGeneration gateway='
      '${AppConstants.useRealtimeGateway} myId=$myId',
    );

    if (AppConstants.useRealtimeGateway) {
      if (!mounted || clearGeneration != _seatSessionGeneration) {
        devLog(
          '[SEAT] clearStale skipped (gen bump) was=$clearGeneration '
          'now=$_seatSessionGeneration',
        );
        return;
      }
      // Nothing to clear on the gateway: the seat state lives server-side and
      // the join already asks for it. _initSeats fires one requestSnapshot and
      // room:join pushes another, so a third here only duplicated work.
      devLog('[SEAT] clearStale → no-op on gateway');
      return;
    }

    if (myId != null) {
      try {
        await Supabase.instance.client
            .from('room_seats')
            .delete()
            .eq('room_id', roomId)
            .eq('user_id', myId);
        devLog('[SEAT] clearStale legacy Postgres delete done');
      } catch (e) {
        devLog('[SEAT] clearStale delete error: $e');
      }
    }
    if (!mounted || clearGeneration != _seatSessionGeneration) return;
    await _fetchSeats();
  }

  Future<bool> _ensureGatewayReady({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (!AppConstants.useRealtimeGateway) return true;
    final roomId = widget.room['id'].toString();
    final socket = RoomRealtimeSocket.instance;
    final sw = Stopwatch()..start();
    final deadline = DateTime.now().add(timeout);
    while (mounted && DateTime.now().isBefore(deadline)) {
      if (socket.isJoinedTo(roomId)) {
        _gatewayJoinReady = true;
        devLog(
          '[SEAT] gatewayReady OK joined=$roomId '
          'ms=${sw.elapsedMilliseconds}',
        );
        return true;
      }
      try {
        await socket.ensureConnected();
        if (socket.isConnected && !socket.isJoinedTo(roomId)) {
          final user = ref.read(userProfileProvider).value;
          if (user != null) {
            devLog('[SEAT] gatewayReady re-join room=$roomId');
            await socket.joinRoom(
              roomId: roomId,
              user: {
                'id': user['id'],
                'username': user['username'],
                'avatar_url': user['avatar_url'],
              },
            );
          }
        }
      } catch (e) {
        devLog('[SEAT] gatewayReady ensure/join error: $e');
        _gatewayJoinReady = false;
      }
      if (socket.isJoinedTo(roomId)) {
        _gatewayJoinReady = true;
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    final ok = mounted && socket.isJoinedTo(roomId);
    _gatewayJoinReady = ok;
    devLog(
      '[SEAT] gatewayReady end ok=$ok flag=$_gatewayJoinReady '
      'joined=${socket.joinedRoomId} connected=${socket.isConnected} '
      'ms=${sw.elapsedMilliseconds}',
    );
    return ok;
  }

  Future<bool> _claimSeatWithRetry({
    required int index,
    required String userId,
    required Map<String, dynamic> userSnapshot,
    required bool isMuted,
  }) async {
    devLog(
      '[SEAT] claimRetry start seat=$index user=$userId muted=$isMuted '
      'zegoReady=$_zegoLoginReady gatewayFlag=$_gatewayJoinReady '
      'joined=${RoomRealtimeSocket.instance.joinedRoomId}',
    );
    for (var attempt = 0; attempt < 3; attempt++) {
      devLog('[SEAT] claimRetry attempt=${attempt + 1}/3');
      final readySw = Stopwatch()..start();
      if (!await _ensureGatewayReady(
        timeout: attempt == 0
            ? const Duration(seconds: 12)
            : const Duration(seconds: 4),
      )) {
        devLog('[SEAT] claimRetry gateway not ready → retry wait');
        await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        continue;
      }
      final readyMs = readySw.elapsedMilliseconds;
      final rpcSw = Stopwatch()..start();
      final claimed = await _broadcastSeatAction(
        action: 'sit',
        seatIndex: index,
        userId: userId,
        user: userSnapshot,
        isMuted: isMuted,
      );
      devLog(
        '[SEAT] claimRetry attempt=${attempt + 1} claimed=$claimed '
        'gatewayReady=${readyMs}ms rpc=${rpcSw.elapsedMilliseconds}ms',
      );
      if (claimed) return true;
      await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
    }
    devLog('[SEAT] claimRetry FAILED after 3 attempts seat=$index');
    return false;
  }

  Future<bool> _ensureVoiceRoomReady({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final sw = Stopwatch()..start();
    final deadline = DateTime.now().add(timeout);
    while (mounted && DateTime.now().isBefore(deadline)) {
      final gatewayOk = await _ensureGatewayReady(
        timeout: const Duration(milliseconds: 200),
      );
      if (_zegoLoginReady && gatewayOk) {
        devLog(
          '[SEAT] voiceReady OK zego=$_zegoLoginReady gateway=$gatewayOk '
          'ms=${sw.elapsedMilliseconds}',
        );
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    final gatewayOk = await _ensureGatewayReady(
      timeout: const Duration(milliseconds: 200),
    );
    final ok = mounted && _zegoLoginReady && gatewayOk;
    devLog(
      '[SEAT] voiceReady end ok=$ok zego=$_zegoLoginReady gateway=$gatewayOk '
      'ms=${sw.elapsedMilliseconds}',
    );
    return ok;
  }

  Future<void> _fetchRoomDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select('*, room_stats(*)')
          .eq('id', widget.room['id'])
          .single();

      if (mounted) {
        setState(() {
          _roomData = Map<String, dynamic>.from(response);
        });
        if (!_mediaResumedFromKeepAlive) {
          await _youtubeSync.syncFromRoomState(
            _parseRoomJsonField(_roomData!['youtube_state']) ?? {},
          );
          await _sharedAudioSync.syncFromRoomState(
            _parseRoomJsonField(_roomData!['shared_audio_state']) ?? {},
          );
        }
        _mediaResumedFromKeepAlive = false;
      }
    } catch (e) {
      devLog('Fetch Room Error: $e');
    }
  }

  Future<void> _ensureRoomShortIdLoaded() async {
    final current = _roomData ?? widget.room;
    if (current['short_id'] != null) return;
    try {
      final row = await Supabase.instance.client
          .from('rooms')
          .select('short_id')
          .eq('id', widget.room['id'])
          .maybeSingle();
      final sid = row?['short_id'];
      if (sid == null || !mounted) return;
      setState(() {
        _roomData ??= Map<String, dynamic>.from(widget.room);
        _roomData!['short_id'] = sid;
      });
    } catch (e) {
      debugPrint('[Room] short_id fetch failed: $e');
    }
  }

  Future<void> _refreshSeatGiftTotals() async {
    if (AppConstants.useRealtimeGateway) return;

    final supabase = Supabase.instance.client;
    final Map<String, int> newGiftTotals = {};
    try {
      final giftsResponse = await supabase
          .from('gift_logs')
          .select('receiver_id, amount, charm_amount')
          .eq('room_id', widget.room['id']);

      for (var log in giftsResponse as List) {
        final receiverId = log['receiver_id'] as String?;
        if (receiverId != null) {
          final charm = (log['charm_amount'] as num?)?.toInt();
          final amount = charm != null && charm > 0
              ? charm
              : (log['amount'] as num?)?.toInt() ?? 0;
          newGiftTotals[receiverId] = (newGiftTotals[receiverId] ?? 0) + amount;
        }
      }
      if (mounted) {
        setState(() => _seatGiftTotals = newGiftTotals);
      }
    } catch (e) {
      debugPrint('Error fetching gift logs for seats: $e');
    }
  }

  Future<void> _fetchSeats({
    bool refreshGiftTotals = true,
    bool force = false,
  }) async {
    devLog(
      '[SEAT] fetchSeats force=$force skipWindow='
      '${RoomSeatSyncService.shouldSkipFetch(_lastSeatBroadcastAt)} '
      'mySeat=$_mySeatIndex gateway=${AppConstants.useRealtimeGateway}',
    );
    if (!force && RoomSeatSyncService.shouldSkipFetch(_lastSeatBroadcastAt)) {
      devLog('[SEAT] fetchSeats SKIP (recent broadcast window)');
      return;
    }

    if (AppConstants.useRealtimeGateway && !force) {
      devLog('[SEAT] fetchSeats → gateway snapshot (no Postgres wipe)');
      final roomId = widget.room['id'].toString();
      unawaited(() async {
        final snap = await RoomRealtimeSocket.instance.requestSnapshot(roomId);
        if (!mounted || snap == null || snap['ok'] == false) return;
        if (snap['seats'] is! List) return;
        _applyGatewaySnapshot(snap);
      }());
      return;
    }

    final generation = ++_fetchSeatsGeneration;
    devLog('[SEAT] fetchSeats Postgres path gen=$generation force=$force');
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('room_seats')
        .select('*, user:user_id(id, username, avatar_url, vip_level)')
        .eq('room_id', widget.room['id']);

    if (!mounted || generation != _fetchSeatsGeneration) return;

    if (refreshGiftTotals && !AppConstants.useRealtimeGateway) {
      unawaited(_refreshSeatGiftTotals());
    }

    if (!mounted || generation != _fetchSeatsGeneration) return;

    final myId = supabase.auth.currentUser?.id;
    final previousSeatIndex = _mySeatIndex;
    final previousMuted = _isMuted;
    final previousSeats = _seats
        .map((s) => Map<String, dynamic>.from(s))
        .toList(growable: false);
    final previousSeatedUserIds = previousSeats
        .map((s) => _normalizePresenceUserId(s['user_id']))
        .whereType<String>()
        .toSet();
    final dbByIndex = <int, Map<String, dynamic>>{};
    for (final seatData in response as List) {
      final idx = (seatData['seat_index'] as num?)?.toInt();
      if (idx == null || idx < 0) continue;
      dbByIndex[idx] = Map<String, dynamic>.from(seatData);
    }

    SeatWearCache.ingestSeats(dbByIndex.values);
    if (mounted) {
      setState(() {
        _mySeatIndex = null;
        for (int i = 0; i < _seats.length; i++) {
          final locked = _seats[i]['is_locked'] == true;
          _seats[i] = {
            'index': i,
            'user_id': null,
            'user': null,
            'is_muted': false,
            'is_locked': locked,
          };
        }
        for (final entry in dbByIndex.entries) {
          final idx = entry.key;
          if (idx < 0 || idx >= _seats.length) continue;
          final seatData = entry.value;
          final uid = seatData['user_id']?.toString();
          if (uid != null &&
              RoomSeatSyncService.wasRecentlyVacated(
                _recentlyVacatedSeatUsers,
                uid,
              )) {
            continue;
          }
          _seats[idx] = Map<String, dynamic>.from(seatData);
          if (uid == myId) {
            _mySeatIndex = idx;
            _isMuted = seatData['is_muted'] == true;
          }
        }

        for (var i = 0; i < _seats.length && i < previousSeats.length; i++) {
          final local = previousSeats[i];
          if (_shouldPreserveLocalSeatOccupant(local, dbByIndex[i])) {
            _seats[i] = Map<String, dynamic>.from(local)..['index'] = i;
            if (local['user_id']?.toString() == myId) {
              _mySeatIndex = i;
              _isMuted = local['is_muted'] == true;
            }
          }
        }
        _updateAudienceList();
      });

      devLog(
        '[SEAT] fetchSeats applied prevMy=$previousSeatIndex '
        'nextMy=$_mySeatIndex dbRows=${dbByIndex.length}',
      );

      final currentSeatedUserIds = _seats
          .map((s) => _normalizePresenceUserId(s['user_id']))
          .whereType<String>()
          .toSet();
      final leftSeatUserIds = previousSeatedUserIds.difference(
        currentSeatedUserIds,
      );
      if (leftSeatUserIds.isNotEmpty) {
        devLog('[SEAT] fetchSeats users left seats: $leftSeatUserIds');
        _onlineUsers.removeWhere((u) {
          final id = _normalizePresenceUserId(u['id']);
          return id != null && leftSeatUserIds.contains(id);
        });
        _knownPresenceUserIds.removeAll(leftSeatUserIds);
        _updateAudienceList();
      }

      final seatedUserIds = _seats
          .map((s) => s['user_id']?.toString())
          .whereType<String>()
          .toSet();
      final staleSoundIds = _soundLevels.keys
          .where((id) => !seatedUserIds.contains(id))
          .toList();
      if (staleSoundIds.isNotEmpty) {
        for (final id in staleSoundIds) {
          _soundLevels.remove(id);
          _speakSticky.remove(id);
          _speakHoldTimers.remove(id)?.cancel();
        }
        if (!_soundLevelsDisposed) _soundLevelsVersion.value++;
      }

      if (_mySeatIndex != null) {
        final seatChanged = previousSeatIndex != _mySeatIndex;
        var muteChanged = previousMuted != _isMuted;
        if (_isMuted &&
            !previousMuted &&
            _localUnmuteGuardUntil != null &&
            DateTime.now().isBefore(_localUnmuteGuardUntil!)) {
          _isMuted = false;
          if (_mySeatIndex! < _seats.length) {
            _seats[_mySeatIndex!]['is_muted'] = false;
          }
          muteChanged = false;
        }
        if (!_isMuted &&
            previousMuted &&
            _localMuteGuardUntil != null &&
            DateTime.now().isBefore(_localMuteGuardUntil!)) {
          _isMuted = true;
          if (_mySeatIndex! < _seats.length) {
            _seats[_mySeatIndex!]['is_muted'] = true;
          }
          muteChanged = false;
        }
        if (_isMuted && !previousMuted) {
          _localUnmuteGuardUntil = null;
          _localMuteGuardUntil = DateTime.now().add(const Duration(seconds: 8));
        }
        if (seatChanged || muteChanged) {
          devLog(
            '[SEAT] fetchSeats re-publish seatChanged=$seatChanged '
            'muteChanged=$muteChanged',
          );
          if (_useOrbitVoice) {
            final inSync =
                OrbitVoiceSessionService.isConnected &&
                _orbitCanPublish &&
                _isLocalPublishing == !_isMuted;
            if (!inSync) {
              unawaited(_startSpeaking(!_isMuted));
            }
          } else {
            await _startSpeaking(!_isMuted);
          }
        }
      } else if (previousSeatIndex != null) {
        devLog(
          '[SEAT] fetchSeats WIPED my seat (was $previousSeatIndex) → stopPublish',
        );
        unawaited(_stopSharedAudioIfUploader(reason: 'seat_wiped'));
        await _stopLocalPublishTracked();
        if (mounted) {
          setState(() => _isMuted = true);
        }
      }

      unawaited(_refreshSeatCpPartners());
    }
  }

  Future<void> _refreshSeatCpPartners() async {
    final generation = ++_cpPartnerRefreshGeneration;
    final ids = _seats
        .map((s) => s['user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    if (ids.isEmpty) {
      if (!mounted || generation != _cpPartnerRefreshGeneration) return;
      if (_cpPartnerByUserId.isNotEmpty) {
        setState(() => _cpPartnerByUserId = {});
      }
      return;
    }

    try {
      final idList = ids.join(',');
      final response = await Supabase.instance.client
          .from('couples')
          .select('user1_id, user2_id')
          .or('user1_id.in.($idList),user2_id.in.($idList)');

      if (!mounted || generation != _cpPartnerRefreshGeneration) return;

      final seated = ids.toSet();
      final next = <String, String>{};
      for (final row in response as List) {
        final u1 = row['user1_id']?.toString();
        final u2 = row['user2_id']?.toString();
        if (u1 == null || u2 == null) continue;
        if (!seated.contains(u1) || !seated.contains(u2)) continue;
        next[u1] = u2;
        next[u2] = u1;
      }

      var changed = next.length != _cpPartnerByUserId.length;
      if (!changed) {
        for (final e in next.entries) {
          if (_cpPartnerByUserId[e.key] != e.value) {
            changed = true;
            break;
          }
        }
      }
      if (changed) {
        setState(() => _cpPartnerByUserId = next);
      }
    } catch (e) {
      debugPrint('CP partner refresh failed: $e');
    }
  }

  bool _areAdjacentSeatCp(int leftIndex, int rightIndex) {
    if (leftIndex < 0 ||
        rightIndex < 0 ||
        leftIndex >= _seats.length ||
        rightIndex >= _seats.length) {
      return false;
    }
    final a = _seats[leftIndex]['user_id']?.toString();
    final b = _seats[rightIndex]['user_id']?.toString();
    if (a == null || b == null || a == b) return false;
    return _cpPartnerByUserId[a] == b;
  }

  Future<void> _startSpeaking(bool shouldOpenMic) async {
    if (!shouldOpenMic) return _startSpeakingUnguarded(false);
    _startSpeakingOpenInFlight++;
    try {
      await _startSpeakingUnguarded(true);
    } finally {
      _startSpeakingOpenInFlight--;
    }
  }

  Future<void> _startSpeakingUnguarded(bool shouldOpenMic) async {
    if (ref.read(userProfileProvider).value == null) return;
    // #region agent log
    DebugProbe.log('A', 'room_live_screen:_startSpeaking', 'startSpeaking entry', {
      'openMic': shouldOpenMic,
      'liveForRoom':
          OrbitVoiceSessionService.isLiveForRoom(widget.room['id'].toString()),
      'canPublishNow': OrbitVoiceSessionService.canPublishNow,
      'orbitCanPublish': _orbitCanPublish,
      'muted': _isMuted,
    });
    // #endregion
    devLog(
      '[SEAT] startSpeaking openMic=$shouldOpenMic '
      'zegoReady=$_zegoLoginReady mySeat=$_mySeatIndex '
      'publishing=$_isLocalPublishing backend=${_voiceBackend.name}',
    );

    if (_useOrbitVoice) {
      final roomId = widget.room['id'].toString();
      final onSeat = _mySeatIndex != null;
      if (shouldOpenMic && _isMuted) {
        debugPrint('[ORBIT] startSpeaking skip open — locally muted');
        await _syncOrbitMicAndBilling(
          roomId: roomId,
          openMic: false,
          onSeat: onSeat,
        );
        return;
      }
      if (!shouldOpenMic) {
        if (onSeat &&
            (!OrbitVoiceSessionService.isConnected || !_orbitCanPublish)) {
          await _initOrbitVoice(openMic: false);
        } else {
          await _syncOrbitMicAndBilling(
            roomId: roomId,
            openMic: false,
            onSeat: onSeat,
          );
        }
        debugPrint('[ORBIT] startSpeaking mic off (billing stop)');
        return;
      }
      var status = await Permission.microphone.request();
      if (!status.isGranted) {
        _addSystemMessage('Microphone permission is required to speak.');
        return;
      }
      if (_isMuted) {
        debugPrint(
          '[ORBIT] startSpeaking abort open — muted during permission',
        );
        return;
      }
      if (OrbitVoiceSessionService.isLiveForRoom(roomId)) {
        // Already connected to this room, as a listener or a speaker. seat:sit
        // grants publish on this live connection (UpdateParticipant) and that
        // grant lands on the signalling socket at about the same time as the
        // ack, so wait for it briefly and publish in place. Reconnecting to
        // pick up the new token tore down both peer connections and made the
        // server evict the old session first — several seconds before anyone
        // could hear the new speaker. The reconnect remains the fallback.
        final grantSw = Stopwatch()..start();
        var granted = OrbitVoiceSessionService.canPublishNow;
        if (!granted) {
          granted = await OrbitVoiceSessionService.waitForPublishPermission(
            timeout: const Duration(milliseconds: 1500),
          );
        }
        if (granted && !_isMuted && _mySeatIndex != null) {
          _orbitCanPublish = true;
          await _syncOrbitMicAndBilling(
            roomId: roomId,
            openMic: true,
            onSeat: onSeat,
          );

          if (!OrbitVoiceSessionService.hasMicPublication &&
              !OrbitVoiceSessionService.hasLiveMicTrack) {
            debugPrint(
              '[ORBIT] startSpeaking publish grant soft — forcing remint',
            );
            await _initOrbitVoice(openMic: true);
          } else {
            // The publish token from the sit ack is no longer needed; drop it
            // so a later listener-only request cannot pick it up by mistake.
            RoomRealtimeSocket.instance.takeVoiceSession(roomId);
            debugPrint(
              '[ORBIT] startSpeaking mic on in place '
              'grant=${grantSw.elapsedMilliseconds}ms '
              'publishing=$_isLocalPublishing '
              'pub=${OrbitVoiceSessionService.hasMicPublication}',
            );
          }
          return;
        }
        if (!granted) {
          debugPrint(
            '[ORBIT] startSpeaking no live publish grant after '
            '${grantSw.elapsedMilliseconds}ms — reconnecting with sit token',
          );
        }
      }
      await _initOrbitVoice(openMic: true);
      return;
    }
  }

  void _scheduleVoiceHeal(String reason) {
    _voiceHealDebounce?.cancel();
    _voiceHealDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_healLocalVoiceIfNeeded(reason: reason));
    });
  }

  void _scheduleOrbitHearingHeal(String reason) {
    _voiceHealDebounce?.cancel();
    _voiceHealDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_healOrbitHearingIfNeeded(reason: reason));
    });
  }

  Future<void> _healOrbitHearingIfNeeded({required String reason}) async {
    if (!mounted || !_useOrbitVoice) return;
    if (_voiceHealInFlight) return;
    _voiceHealInFlight = true;
    try {
      if (!OrbitVoiceSessionService.isConnected) {
        debugPrint('[ORBIT] hearing heal reconnect ($reason)');
        await _initOrbitVoice(openMic: false);
        return;
      }
      debugPrint('[ORBIT] hearing heal reassert ($reason)');
      await OrbitVoiceSessionService.reassertRemoteHearing('heal_$reason');
      await OrbitVoiceSessionService.setRemoteAudioMuted(_roomAudioMuted);
      await OrbitVoiceSessionService.setSpeakerOn(_audioRouteToSpeaker);
      unawaited(_sharedAudioSync.reassertPlaybackOutput());
    } finally {
      _voiceHealInFlight = false;
    }
  }

  Future<void> _healLocalVoiceIfNeeded({required String reason}) async {
    if (!mounted) return;
    if (_mySeatIndex == null) {
      _scheduleOrbitHearingHeal(reason);
      return;
    }
    if (_voiceHealInFlight) return;
    if (!_isMuted && _startSpeakingOpenInFlight > 0) {
      // The publish this heal would ask for is already underway; re-entering
      // _startSpeaking now would only cancel it and start over.
      debugPrint('[VOICE] skip heal ($reason) — publish already in flight');
      return;
    }
    if (_isMuted &&
        _localUnmuteGuardUntil != null &&
        DateTime.now().isBefore(_localUnmuteGuardUntil!)) {
      debugPrint('[VOICE] skip heal mute ($reason) — local unmute guard');
      _isMuted = false;
      if (_mySeatIndex != null && _mySeatIndex! < _seats.length) {
        _seats[_mySeatIndex!]['is_muted'] = false;
      }
      return;
    }
    if (!_isMuted &&
        _localMuteGuardUntil != null &&
        DateTime.now().isBefore(_localMuteGuardUntil!)) {
      debugPrint('[VOICE] skip heal unmute ($reason) — local mute guard');
      _isMuted = true;
      if (_mySeatIndex != null && _mySeatIndex! < _seats.length) {
        _seats[_mySeatIndex!]['is_muted'] = true;
      }
      return;
    }
    if (_useOrbitVoice &&
        OrbitVoiceSessionService.isConnected &&
        _orbitCanPublish &&
        _isLocalPublishing == !_isMuted &&
        (_isMuted || OrbitVoiceSessionService.hasLiveMicTrack)) {
      debugPrint('[ORBIT] heal skip ($reason) — already in sync');
      unawaited(
        OrbitVoiceSessionService.reassertRemoteHearing('heal_skip_$reason'),
      );
      return;
    }
    _voiceHealInFlight = true;
    try {
      devLog(
        '[VOICE] heal reason=$reason muted=$_isMuted '
        'publishing=$_isLocalPublishing seat=$_mySeatIndex',
      );
      await _startSpeaking(!_isMuted);
      if (_useOrbitVoice) {
        unawaited(
          OrbitVoiceSessionService.reassertRemoteHearing('heal_done_$reason'),
        );
      }
    } finally {
      _voiceHealInFlight = false;
    }
  }

  Future<void> _stopLocalPublishTracked() async {
    _isLocalPublishing = false;
    await _syncOrbitMicAndBilling(
      roomId: widget.room['id'].toString(),
      openMic: false,
      onSeat: _mySeatIndex != null,
    );
  }

  Future<void> _loadChatAndWelcome() async {
    await _fetchRoomDetails();
    if (mounted) {
      _clearChatMessages();
      _addLocalSystemMessage(_kRoomEntryWarning);
      _addLocalSystemMessage('Welcome to ${_roomData!['title']}!');

      final selfName =
          ref.read(userProfileProvider).value?['username'] ?? 'User';
      _addLocalSystemMessage(
        '$selfName entered the room',
        aboutUserId: Supabase.instance.client.auth.currentUser?.id,
      );
    }
  }

  Future<void> _fetchMessages() async {}

  void _clearMentionPicker() {
    _mentionQuery = null;
    _mentionAtIndex = null;
    _mentionSuggestions = [];
  }

  List<Map<String, dynamic>> _seatedMembersForMention() {
    final members = <Map<String, dynamic>>[];
    for (final seat in _seats) {
      final userId = seat['user_id']?.toString();
      if (userId == null || userId.isEmpty) continue;
      final user = seat['user'];
      final username = user is Map
          ? (user['username']?.toString() ?? 'User')
          : 'User';
      final avatar = user is Map ? user['avatar_url'] : null;
      members.add({'id': userId, 'username': username, 'avatar_url': avatar});
    }
    return members;
  }

  List<Map<String, dynamic>> _mentionCandidates() {
    final selfId = Supabase.instance.client.auth.currentUser?.id;
    final byId = <String, Map<String, dynamic>>{};

    void add(Map<String, dynamic> u, {required bool seated}) {
      final id = u['id']?.toString();
      if (id == null || id.isEmpty || id == selfId) return;
      final username = (u['username'] ?? 'User').toString().trim();
      if (username.isEmpty) return;
      final existing = byId[id];
      if (existing != null) {
        if (seated) existing['seated'] = true;
        return;
      }
      byId[id] = {
        'id': id,
        'username': username,
        'avatar_url': u['avatar_url'],
        'seated': seated,
      };
    }

    for (final m in _seatedMembersForMention()) {
      add(m, seated: true);
    }
    for (final u in _onlineUsers) {
      add(u, seated: false);
    }
    for (final u in _audience) {
      add(u, seated: false);
    }

    final list = byId.values.toList();
    list.sort((a, b) {
      final sa = a['seated'] == true ? 0 : 1;
      final sb = b['seated'] == true ? 0 : 1;
      if (sa != sb) return sa - sb;
      return (a['username'] as String).toLowerCase().compareTo(
        (b['username'] as String).toLowerCase(),
      );
    });
    return list;
  }

  void _onRoomChatTextChanged() {
    if (!mounted) return;
    final text = _messageController.text;
    final selection = _messageController.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;

    _pendingMentions.removeWhere((m) {
      final name = (m['username'] ?? '').toString();
      if (name.isEmpty) return true;
      return !RegExp(
        '@${RegExp.escape(name)}(?![\\w.\\-])',
        caseSensitive: false,
      ).hasMatch(text);
    });

    if (cursor <= 0 || cursor > text.length) {
      if (_mentionQuery != null) setState(_clearMentionPicker);
      return;
    }

    final before = text.substring(0, cursor);
    final match = RegExp(r'@([\w.\-]*)$').firstMatch(before);
    if (match == null) {
      if (_mentionQuery != null) setState(_clearMentionPicker);
      return;
    }

    final atIndex = match.start;
    if (atIndex > 0) {
      final prev = before[atIndex - 1];
      if (RegExp(r'[\w.]').hasMatch(prev)) {
        if (_mentionQuery != null) setState(_clearMentionPicker);
        return;
      }
    }

    final query = match.group(1) ?? '';
    final q = query.toLowerCase();
    final suggestions = _mentionCandidates()
        .where((c) {
          final name = (c['username'] as String).toLowerCase();
          return q.isEmpty || name.contains(q);
        })
        .take(8)
        .toList();

    setState(() {
      _mentionAtIndex = atIndex;
      _mentionQuery = query;
      _mentionSuggestions = suggestions;
    });
  }

  void _applyMention(Map<String, dynamic> user) {
    final username = (user['username'] ?? 'User').toString().trim();
    final userId = user['id']?.toString();
    if (username.isEmpty || userId == null) return;

    final text = _messageController.text;
    final atIndex = _mentionAtIndex;
    final selection = _messageController.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    if (atIndex == null || atIndex < 0 || atIndex >= cursor) {
      _clearMentionPicker();
      return;
    }

    final before = text.substring(0, atIndex);
    final after = cursor <= text.length ? text.substring(cursor) : '';
    final insertion = '@$username ';
    final newText = '$before$insertion$after';
    final newCursor = before.length + insertion.length;

    if (!_pendingMentions.any((m) => m['user_id']?.toString() == userId)) {
      _pendingMentions.add({'user_id': userId, 'username': username});
    }

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    setState(_clearMentionPicker);
  }

  List<Map<String, dynamic>> _resolveMentionsForSend(String text) {
    final byId = <String, Map<String, dynamic>>{};
    for (final m in _pendingMentions) {
      final id = m['user_id']?.toString();
      final name = (m['username'] ?? '').toString();
      if (id == null || name.isEmpty) continue;
      if (!RegExp(
        '@${RegExp.escape(name)}(?![\\w.\\-])',
        caseSensitive: false,
      ).hasMatch(text)) {
        continue;
      }
      byId[id] = {'user_id': id, 'username': name};
    }

    final candidates = _mentionCandidates();
    for (final match in RegExp(r'@([\w.\-]+)').allMatches(text)) {
      final token = match.group(1)!.toLowerCase();
      Map<String, dynamic>? found;
      for (final c in candidates) {
        if ((c['username'] as String).toLowerCase() == token) {
          found = c;
          break;
        }
      }
      if (found == null) continue;
      final id = found['id']!.toString();
      byId.putIfAbsent(
        id,
        () => {'user_id': id, 'username': found!['username']},
      );
    }
    return byId.values.toList();
  }

  String _lookupUsername(String userId, {String? fallback}) {
    var name = (fallback ?? '').trim();
    if (name.isNotEmpty) return name;
    for (final c in _mentionCandidates()) {
      if (c['id']?.toString() == userId) {
        name = (c['username'] ?? '').toString().trim();
        if (name.isNotEmpty) return name;
      }
    }
    for (final seat in _seats) {
      if (seat['user_id']?.toString() == userId) {
        name = seat['user']?['username']?.toString().trim() ?? '';
        if (name.isNotEmpty) return name;
      }
    }
    return '';
  }

  void _mentionUserFromProfile(String userId, {String? username}) {
    final name = _lookupUsername(userId, fallback: username);
    if (name.isEmpty) return;

    final text = _messageController.text;
    final needsSpace = text.isNotEmpty && !text.endsWith(' ');
    final insertion = '${needsSpace ? ' ' : ''}@$name ';
    final newText = '$text$insertion';
    if (!_pendingMentions.any((m) => m['user_id']?.toString() == userId)) {
      _pendingMentions.add({'user_id': userId, 'username': name});
    }
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    if (!_isRoomChatExpanded) {
      _isRoomChatExpanded = true;
      _chatBarOpen.value = true;
    }
    _chatFocusNode.requestFocus();
  }

  void _reminderFromMiniProfile(String userId, {String? username}) {
    _mentionUserFromProfile(userId, username: username);
  }

  void _sayHiFromMiniProfile(String userId, {String? username}) {
    final name = _lookupUsername(userId, fallback: username);
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not load username')));
      return;
    }
    if (!_pendingMentions.any((m) => m['user_id']?.toString() == userId)) {
      _pendingMentions.add({'user_id': userId, 'username': name});
    }
    _messageController.value = TextEditingValue(
      text: 'Hi @$name',
      selection: TextSelection.collapsed(offset: 'Hi @$name'.length),
    );
    _isRoomChatExpanded = true;
    _chatBarOpen.value = true;
    unawaited(_sendMessage());
  }

  void _showUserMiniProfile(String userId, {String? username, int? seatIndex}) {
    if (userId.isEmpty) return;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isSelf = myId != null && userId == myId;
    final resolvedName = _lookupUsername(userId, fallback: username);

    int? resolvedSeat = seatIndex;
    if (resolvedSeat == null ||
        resolvedSeat < 0 ||
        resolvedSeat >= _seats.length ||
        _seats[resolvedSeat]['user_id']?.toString() != userId) {
      final found = _seats.indexWhere(
        (s) => s['user_id']?.toString() == userId,
      );
      resolvedSeat = found >= 0 ? found : null;
    }
    final onSeat = resolvedSeat != null;
    final isMutedOnSeat =
        resolvedSeat != null && _seats[resolvedSeat]['is_muted'] == true;
    final canManage = _canManageRoom && !isSelf;
    final canKick = _canKickUser(userId);

    UserProfileMiniSheet.show(
      context,
      userId,
      onSendGift: () {
        _giftTargetUserIds
          ..clear()
          ..add(userId);
        _giftTargetAllSelected = false;
        _showGiftSheet();
      },
      onMention: () => _reminderFromMiniProfile(userId, username: resolvedName),
      roomActions: isSelf
          ? null
          : UserProfileMiniRoomActions(
              forceModRow: canManage,
              showMute: canManage && onSeat && !isMutedOnSeat,
              showBanChat: canManage,
              showStandUp: canManage && onSeat,
              showKick: canKick,
              onMute: canManage && onSeat && !isMutedOnSeat
                  ? () => _muteUser(resolvedSeat!)
                  : null,
              onBanChat: canManage
                  ? () {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ban Chat coming soon'),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                    }
                  : null,
              onStandUp: canManage && onSeat
                  ? () => _removeUserFromSeat(resolvedSeat!)
                  : null,
              onKick: canKick
                  ? () => _kickUserFromRoom(
                      userId,
                      resolvedName.isNotEmpty ? resolvedName : 'User',
                    )
                  : null,
              onSayHi: (name) => _sayHiFromMiniProfile(userId, username: name),
              onReminder: (name) =>
                  _reminderFromMiniProfile(userId, username: name),
            ),
    );
  }

  void _handleOccupiedSeatTap(int index) {
    if (index < 0 || index >= _seats.length) return;
    final seat = _seats[index];
    final seatUserId = seat['user_id']?.toString() ?? '';
    if (seatUserId.isEmpty) return;

    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (seatUserId == myId || _canManageRoom) {
      unawaited(_handleSeatTap(index));
      return;
    }
    _showOccupiedSeatMiniProfile(index);
  }

  void _showOccupiedSeatMiniProfile(int index) {
    if (index < 0 || index >= _seats.length) return;
    final seat = _seats[index];
    final seatUserId = seat['user_id']?.toString() ?? '';
    if (seatUserId.isEmpty) return;

    _showUserMiniProfile(
      seatUserId,
      username: seat['user']?['username']?.toString(),
      seatIndex: index,
    );
  }

  Widget _buildMentionSuggestions() {
    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 140),
        decoration: BoxDecoration(
          color: const Color(0xF0121218),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _mentionSuggestions.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          itemBuilder: (context, index) {
            final user = _mentionSuggestions[index];
            final username = user['username']?.toString() ?? 'User';
            final avatar = user['avatar_url']?.toString();
            final seated = user['seated'] == true;
            return InkWell(
              onTap: () => _applyMention(user),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: avatar != null && avatar.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: avatar,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const ColoredBox(
                                  color: Colors.white12,
                                  child: Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.white38,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => const ColoredBox(
                                  color: Colors.white12,
                                  child: Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.white38,
                                  ),
                                ),
                              )
                            : const ColoredBox(
                                color: Colors.white12,
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.white38,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (seated)
                      Text(
                        'Seat',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_roomData?['admin_only_chat'] == true && !_canManageRoom) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.room_chatRestrictedAdmins),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      _messageController.clear();
      _pendingMentions.clear();
      _clearMentionPicker();
      _chatFocusNode.unfocus();
      return;
    }

    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    final mentions = _resolveMentionsForSend(text);
    final eventId = RoomLiveBroadcast.newEventId();
    final bubbleMeta = await _equippedBubbleMetadataAsync(
      user['id']?.toString(),
    );
    final metadata = <String, dynamic>{
      'event_id': eventId,
      if (mentions.isNotEmpty) 'mentions': mentions,
      ...bubbleMeta,
    };

    _messageController.clear();
    _pendingMentions.clear();
    _clearMentionPicker();
    final sentAt = DateTime.now().toUtc().toIso8601String();

    if (mounted) {
      _tryAppendChatMessage({
        'id': eventId,
        'user_id': user['id'],
        'content': text,
        'type': 'chat',
        'created_at': sentAt,
        'user': user,
        'metadata': Map<String, dynamic>.from(metadata),
      });
    }

    unawaited(
      _broadcastChat(
        eventId: eventId,
        type: 'chat',
        content: text,
        userId: user['id']?.toString(),
        user: Map<String, dynamic>.from(user),
        metadata: Map<String, dynamic>.from(metadata),
      ),
    );

    if (!AppConstants.useRealtimeGateway) {
      unawaited(
        _persistRoomMessage({
          'room_id': widget.room['id'],
          'user_id': user['id'],
          'content': text,
          'type': 'chat',
          'metadata': Map<String, dynamic>.from(metadata),
        }),
      );
    }
  }

  void _showRoomImageSourceSheet() {
    if (_roomData?['admin_only_chat'] == true && !_canManageRoom) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.room_chatRestrictedAdmins),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ListTile(
              leading: const Icon(Iconsax.gallery, color: Colors.white),
              title: const Text(
                'Choose from gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_sendRoomImage(ImageSource.gallery));
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.camera, color: Colors.white),
              title: const Text(
                'Take a photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_sendRoomImage(ImageSource.camera));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sendRoomImage(ImageSource source) async {
    if (_roomData?['admin_only_chat'] == true && !_canManageRoom) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.room_chatRestrictedAdmins),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final picked = await RoomChatImageService.pick(source);
    if (picked == null || !mounted) return;

    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    final eventId = RoomLiveBroadcast.newEventId();
    final sentAt = DateTime.now().toUtc().toIso8601String();
    final caption = _messageController.text.trim();
    _messageController.clear();

    final bubbleMeta = await _equippedBubbleMetadataAsync(
      user['id']?.toString(),
    );

    if (mounted) {
      _tryAppendChatMessage({
        'id': eventId,
        'user_id': user['id'],
        'content': caption,
        'type': 'image',
        'created_at': sentAt,
        'user': user,
        'metadata': {
          'event_id': eventId,
          'local_path': picked.path,
          'uploading': true,
          ...bubbleMeta,
        },
      });
    }

    final url = await ChatService.uploadMedia(
      File(picked.path),
      RoomChatImageService.uploadFolder,
    );

    if (!mounted) return;

    if (url == null) {
      _messages.removeWhere((m) => m['id']?.toString() == eventId);
      _notifyChatListChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.room_couldNotUploadPhoto),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final metadata = <String, dynamic>{
      'event_id': eventId,
      'image_url': url,
      ...bubbleMeta,
    };

    final index = _messages.indexWhere((m) => m['id']?.toString() == eventId);
    if (index != -1) {
      _messages[index] = {..._messages[index], 'metadata': metadata};
      _notifyChatListChanged();
    }

    unawaited(
      _broadcastChat(
        eventId: eventId,
        type: 'image',
        content: caption,
        userId: user['id']?.toString(),
        user: Map<String, dynamic>.from(user),
        metadata: metadata,
      ),
    );

    if (!AppConstants.useRealtimeGateway) {
      unawaited(
        _persistRoomMessage({
          'room_id': widget.room['id'],
          'user_id': user['id'],
          'content': caption,
          'type': 'image',
          'metadata': metadata,
        }),
      );
    }
  }

  Future<void> _saveRoomImageToGallery(String url) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.room_savingPhoto),
        duration: const Duration(seconds: 1),
      ),
    );

    final failure = await RoomChatImageService.saveToGallery(url);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure ?? 'Saved to gallery'),
        backgroundColor: failure != null ? Colors.redAccent : null,
      ),
    );
  }

  Future<void> _toggleMic() async {
    if (_mySeatIndex == null) return;

    final supabase = Supabase.instance.client;
    final previousMuted = _isMuted;
    final newMuteState = !_isMuted;
    final seatIndex = _mySeatIndex!;
    final userId = supabase.auth.currentUser!.id;

    if (!newMuteState) {
      var status = await Permission.microphone.request();
      if (!status.isGranted) {
        _addSystemMessage('Microphone permission is required to speak.');
        return;
      }
    }

    setState(() {
      _isMuted = newMuteState;
      _seats[seatIndex]['is_muted'] = newMuteState;
    });
    if (!newMuteState) {
      _localUnmuteGuardUntil = DateTime.now().add(const Duration(seconds: 8));
      _localMuteGuardUntil = null;
    } else {
      _localUnmuteGuardUntil = null;
      _localMuteGuardUntil = DateTime.now().add(const Duration(seconds: 8));
    }

    final broadcastOk = await _broadcastSeatAction(
      action: 'mute',
      seatIndex: seatIndex,
      userId: userId,
      isMuted: newMuteState,
    );

    if (!broadcastOk && !newMuteState) {
      debugPrint('[MIC] unmute gateway ack failed — keeping local open mic');
      _localUnmuteGuardUntil = DateTime.now().add(const Duration(seconds: 12));
      _localMuteGuardUntil = null;
      unawaited(_startSpeaking(true));
      return;
    }

    if (!broadcastOk) {
      devLog(
        '[MIC] mute broadcast failed — rolling back to muted=$previousMuted',
      );
      if (mounted) {
        setState(() {
          _isMuted = previousMuted;
          _seats[seatIndex]['is_muted'] = previousMuted;
        });
      }
      _localUnmuteGuardUntil = null;
      _localMuteGuardUntil = null;
      try {
        if (!previousMuted) {
          await _startSpeaking(true);
        } else {
          await _stopLocalPublishTracked();
        }
      } catch (e) {
        debugPrint('[MIC] rollback zego fail: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.room_couldNotSyncMic),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (!newMuteState) {
      unawaited(_startSpeaking(true));
    } else {
      await _stopLocalPublishTracked();
    }

    if (AppConstants.useRealtimeGateway) return;

    RoomSeatSyncService.persistAsync(() async {
      await supabase
          .from('room_seats')
          .update({'is_muted': newMuteState})
          .eq('room_id', _roomData!['id'])
          .eq('user_id', userId);
    }, logTag: 'MicToggle');
  }

  void _scrollToBottom({bool animated = true}) {
    void scroll() {
      if (!_chatScrollController.hasClients) return;
      final target = _chatScrollController.position.maxScrollExtent;
      if (animated) {
        _chatScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _chatScrollController.jumpTo(target);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scroll();
      WidgetsBinding.instance.addPostFrameCallback((_) => scroll());
    });
  }

  void _addSystemMessage(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('zego error') ||
        lower.startsWith('zego ') ||
        RegExp(r'^zego\b', caseSensitive: false).hasMatch(text)) {
      debugPrint('[ROOM_CHAT] suppressed system message: $text');
      return;
    }
    final eventId = RoomLiveBroadcast.newEventId();
    final sentAt = DateTime.now().toUtc().toIso8601String();
    _tryAppendChatMessage({
      'id': eventId,
      'type': 'system',
      'content': text,
      'created_at': sentAt,
    });
    unawaited(_broadcastChat(eventId: eventId, type: 'system', content: text));
  }

  /// [aboutUserId] names the person a notice refers to, so an entry line can
  /// be tapped to open their profile. System messages carried no user id at
  /// all, which is why tapping an entry notice did nothing.
  void _addLocalSystemMessage(String text, {String? aboutUserId}) {
    _tryAppendChatMessage({
      'id': RoomLiveBroadcast.newEventId(),
      'type': 'system',
      'content': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      if (aboutUserId != null && aboutUserId.isNotEmpty)
        'user_id': aboutUserId,
    });
  }

  final Set<String> _shownSeatInviteIds = {};

  void _openExitSidebar() {
    if (_exitSidebarOverlay != null) return;
    _sidebarDismissBlockedUntil = DateTime.now().millisecondsSinceEpoch + 400;
    _exitSidebarOverlay = OverlayEntry(
      builder: (context) => _buildExitSidebar(context),
    );
    Overlay.of(context, rootOverlay: true).insert(_exitSidebarOverlay!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showExitSidebar = true);
    });
  }

  void _removeExitSidebarOverlay() {
    final entry = _exitSidebarOverlay;
    if (entry == null) return;
    entry.remove();
    _exitSidebarOverlay = null;
    _showExitSidebar = false;
  }

  void _closeExitSidebar({bool force = false, bool updateState = true}) {
    if (!force &&
        DateTime.now().millisecondsSinceEpoch < _sidebarDismissBlockedUntil) {
      return;
    }
    if (_exitSidebarOverlay == null) return;
    _removeExitSidebarOverlay();
    if (updateState && mounted) {
      setState(() {});
    }
  }

  Future<void> _minimizeRoomKeepingSession({bool autoTriggered = false}) async {
    if (_shouldKeepZegoAlive || _isAutoMinimizing) return;

    if (autoTriggered) {
      _isAutoMinimizing = true;
    } else {
      if (_sidebarActionInProgress) return;
      _sidebarActionInProgress = true;
    }

    try {
      _removeExitSidebarOverlay();
      final profile = ref.read(userProfileProvider).value;
      final roomMap = Map<String, dynamic>.from(_roomData ?? widget.room);
      final avatar = profile?['avatar_url']?.toString().trim();
      roomMap['_bubble_avatar'] = (avatar != null && avatar.isNotEmpty)
          ? avatar
          : (roomMap['image_url'] ?? roomMap['background_url']);
      roomMap['_bubble_muted'] = _isMuted;
      roomMap['_bubble_vip'] = (profile?['vip_level'] as num?)?.toInt() ?? 0;
      final navigator = Navigator.of(context);
      final roomRoute = _subscribedRoute ?? ModalRoute.of(context);

      await _youtubeSync.snapshotPlaybackPosition();
      if (!mounted) return;

      RoomMediaKeepAlive.retain(
        forRoomId: roomMap['id'].toString(),
        youtubeSync: _youtubeSync,
        sharedAudioSync: _sharedAudioSync,
        sharedAudioQueueController: _sharedAudioQueue,
      );
      syncActiveRoomSession(ref, roomMap);
      ref.read(minimizedRoomProvider.notifier).state = roomMap;
      ref.read(currentLiveRoomIdProvider.notifier).state = null;
      ref.read(roomSystemBubbleVisibleProvider.notifier).state = false;
      _shouldKeepZegoAlive = true;
      _canPopRoute = true;

      _presenceHeartbeatTimer?.cancel();
      RoomFloatingBubbleService.micMuted = _isMuted;
      RoomMinimizedKeepAlive.saveVoiceState(
        seatIndex: _mySeatIndex,
        isMuted: _isMuted,
        orbitCanPublish: _orbitCanPublish,
        localPublishing: _isLocalPublishing,
      );
      RoomMinimizedKeepAlive.start(
        roomId: widget.room['id'].toString(),
        user: RoomMinimizedKeepAlive.userPayload(profile: profile),
      );

      if (autoTriggered) {
        if (roomRoute != null) {
          navigator.removeRoute(roomRoute);
        }
      } else {
        navigator.pop();
      }
    } finally {
      if (!autoTriggered) {
        _sidebarActionInProgress = false;
      }
    }
  }

  void _minimizeRoomFromSidebar() {
    unawaited(_minimizeRoomKeepingSession());
  }

  Future<void> _exitRoomFromSidebar() async {
    if (_sidebarActionInProgress) return;
    _sidebarActionInProgress = true;
    try {
      _removeExitSidebarOverlay();
      _shouldKeepZegoAlive = false;
      _canPopRoute = true;
      RoomMinimizedKeepAlive.stop();

      await _stopSharedAudioIfUploader(reason: 'room_exit');

      final roomId = widget.room['id'].toString();
      try {
        BackgroundService.stop();
      } catch (_) {}

      var poppedByCoordinator = false;
      final container = ProviderScope.containerOf(context, listen: false);
      try {
        poppedByCoordinator = await RoomExitCoordinator.leaveRoom(
          ref,
          roomId: roomId,
        );
      } catch (e) {
        debugPrint('[ROOM] exit leaveRoom failed: $e');
        unawaited(RoomVoiceSessionService.stopLocalPublish());
        clearActiveRoomState(container);
        unawaited(
          RoomFloatingBubbleService.hideRoomBubble(
            reason: RoomBubbleHideReason.roomExit,
          ),
        );
        unawaited(_releaseRoomOnExit());
      }

      if (!poppedByCoordinator && mounted) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      }
    } finally {
      _sidebarActionInProgress = false;
    }
  }

  @override
  void deactivate() {
    WidgetsBinding.instance.removeObserver(this);
    OrbitVoiceSessionService.setSpeakerLevelsHandler(null);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (!_isLeavingRoom) {
      WidgetsBinding.instance.addObserver(this);
      OrbitVoiceSessionService.setSpeakerLevelsHandler(
        _applyOrbitSpeakerLevels,
      );
    }
  }

  @override
  void dispose() {
    _isLeavingRoom = true;
    OrbitVoiceSessionService.setSpeakerLevelsHandler(null);
    for (final t in _speakHoldTimers.values) {
      t.cancel();
    }
    _speakHoldTimers.clear();
    unawaited(AppTelemetry.setContext(roomId: null, screen: null));
    _cancelReconnectBanner();
    roomRouteObserver.unsubscribe(this);
    final roomId = widget.room['id'].toString();
    final keepZegoAlive = _shouldKeepZegoAlive;
    final sessionReleased = _roomSessionReleased;
    final channelTeardownDone = _roomChannelTeardownDone;

    try {
      if (ref.read(currentLiveRoomIdProvider) == roomId) {
        ref.read(currentLiveRoomIdProvider.notifier).state = null;
      }
    } catch (e) {
      debugPrint('[RoomLive] dispose liveRoomId clear skipped: $e');
    }

    _removeExitSidebarOverlay();
    _cancelAllEntranceRejoinTimers();
    _presenceSnapshotTimer?.cancel();
    _presenceHeartbeatTimer?.cancel();
    _gatewaySnapshotDebounceTimer?.cancel();
    _snapshotHoldRecheckTimer?.cancel();
    _repeatGiftHideTimer?.cancel();
    _repeatComboTick.dispose();
    _bonusPattiHideTimer?.cancel();
    _cancelPendingLuckyGiftComments();
    _voiceHealDebounce?.cancel();

    if (!keepZegoAlive && AppConstants.useRealtimeGateway) {
      Map<String, dynamic>? profile;
      try {
        profile = ref.read(userProfileProvider).value;
      } catch (_) {}
      RoomMinimizedKeepAlive.stop();
      final exitUserId =
          profile?['id'] ?? Supabase.instance.client.auth.currentUser?.id;
      unawaited(() async {
        if (exitUserId != null) {
          try {
            await RoomRealtimeSocket.instance.seatLeave({
              'roomId': roomId,
              'user_id': exitUserId,
              'event_id': RoomLiveBroadcast.newEventId(),
            });
          } catch (e) {
            debugPrint('[RoomLive] dispose seatLeave failed: $e');
          }
        }
        try {
          await RoomRealtimeSocket.instance.leaveRoom(
            roomId: roomId,
            user: {
              'id': exitUserId,
              'username': profile?['username'],
              'avatar_url': profile?['avatar_url'],
            },
          );
        } catch (e) {
          debugPrint('[RoomLive] dispose leaveRoom failed: $e');
        }
      }());
      RoomRealtimeSocket.instance.onEvent = null;
      RoomRealtimeSocket.instance.onSnapshot = null;
    }

    if (keepZegoAlive) {
      RoomMediaKeepAlive.retain(
        forRoomId: roomId,
        youtubeSync: _youtubeSync,
        sharedAudioSync: _sharedAudioSync,
        sharedAudioQueueController: _sharedAudioQueue,
      );
      _detachSharedAudioSeatPulseListener();
      _sharedAudioSeatPulseUserId = null;
      _releaseEntrancePattiGate();
      _entranceController?.dispose();
      _entranceTimer?.cancel();
      _activityTimer?.cancel();
      _seatsStreamSubscription?.cancel();
      _soundLevelsCooldown?.cancel();
      if (!_soundLevelsDisposed) {
        _soundLevelsVersion.dispose();
        _soundLevelsDisposed = true;
      }
      _chatListVersion.dispose();
      _chatBarOpen.dispose();
      _gamesRev.dispose();
      _stopGiftAnimations();
      WidgetsBinding.instance.removeObserver(this);
      _globalWinChannel?.unsubscribe();
      _chatScrollController.dispose();
      _messageController.removeListener(_onRoomChatTextChanged);
      _messageController.dispose();
      super.dispose();
      return;
    }

    BackgroundService.stop();
    RoomMinimizedKeepAlive.stop();

    _releaseEntrancePattiGate();
    _entranceController?.dispose();
    _entranceTimer?.cancel();
    _activityTimer?.cancel();
    _seatsStreamSubscription?.cancel();
    _youtubeSync.dispose();
    _detachSharedAudioSeatPulseListener();
    _sharedAudioSeatPulseUserId = null;
    unawaited(_sharedAudioQueue.dispose());
    _sharedAudioSync.dispose();
    _soundLevelsCooldown?.cancel();
    if (!_soundLevelsDisposed) {
      _soundLevelsVersion.dispose();
      _soundLevelsDisposed = true;
    }
    _chatListVersion.dispose();
    _chatBarOpen.dispose();
    _gamesRev.dispose();
    _stopGiftAnimations();
    WidgetsBinding.instance.removeObserver(this);

    if (!sessionReleased && !keepZegoAlive) {
      var alreadyCleared = false;
      try {
        alreadyCleared =
            resolveActiveRoomSession(ref) == null &&
            ref.read(currentLiveRoomIdProvider) != roomId;
      } catch (_) {
        alreadyCleared = RoomFloatingBubbleService.cachedSession == null;
      }
      if (alreadyCleared) {
        if (!channelTeardownDone) {
          unawaited(_teardownRoomChannel());
        }
      } else {
        unawaited(_releaseRoomOnExit());
        unawaited(
          RoomFloatingBubbleService.hideRoomBubble(
            reason: RoomBubbleHideReason.roomExit,
          ),
        );
        try {
          clearActiveRoomState(ref);
        } catch (_) {
          RoomFloatingBubbleService.cacheSession(null);
        }
      }
    } else if (!channelTeardownDone) {
      unawaited(_teardownRoomChannel());
    }

    _globalWinChannel?.unsubscribe();
    _chatScrollController.dispose();
    _messageController.removeListener(_onRoomChatTextChanged);
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _releaseRoomOnExit() async {
    if (_roomSessionReleased) return;
    _roomSessionReleased = true;
    _isLeavingRoom = true;
    _cancelReconnectBanner();

    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    final roomId = widget.room['id'].toString();
    final seatIndex = _mySeatIndex;

    try {
      if (_useOrbitVoice) {
        OrbitVoiceSessionService.setTransportLostHandler(null);
        OrbitVoiceSessionService.setSpeakerLevelsHandler(null);
        OrbitVoiceSessionService.silenceForExit(roomId: roomId);
        unawaited(OrbitVoiceSessionService.stopPublishAndLeave(roomId: roomId));
        _orbitCanPublish = false;
        _orbitInitDesiredMic = null;
        _isLocalPublishing = false;
        _zegoLoginReady = false;
      }
      unawaited(
        RoomVoiceSessionService.leaveVoiceRoom(
          roomId,
          myId,
          skipPresenceUntrack: true,
          skipSeatDelete: AppConstants.useRealtimeGateway,
        ),
      );
    } catch (e) {
      debugPrint('[ROOM] leaveVoiceRoom on exit: $e');
      unawaited(RoomVoiceSessionService.forceDestroyEngine());
    }

    if (seatIndex != null && myId != null) {
      try {
        await _broadcastSeatAction(
          action: 'leave',
          seatIndex: seatIndex,
          userId: myId,
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('[ROOM] seat leave broadcast on exit: $e');
      }
    } else if (AppConstants.useRealtimeGateway && myId != null) {
      try {
        await RoomRealtimeSocket.instance
            .seatLeave({
              'roomId': roomId,
              'user_id': myId,
              'event_id': RoomLiveBroadcast.newEventId(),
            })
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('[ROOM] seat leave fallback on exit: $e');
      }
    }

    if (mounted) {
      setState(() {
        _mySeatIndex = null;
        _isMuted = true;
        for (var i = 0; i < _seats.length; i++) {
          if (_seats[i]['user_id']?.toString() == myId) {
            _seats[i]['user_id'] = null;
            _seats[i]['user'] = null;
            _seats[i]['is_muted'] = false;
          }
        }
        _updateAudienceList();
      });
    }

    await _teardownRoomChannel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.detached) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final room = Map<String, dynamic>.from(_roomData ?? widget.room);
      final session = buildActiveRoomSession(room);
      RoomFloatingBubbleService.cacheSession(session);
      try {
        if (mounted) syncActiveRoomSession(ref, room);
      } catch (e) {
        debugPrint('[RoomLive] sync session on pause skipped: $e');
      }
    }

    if (state == AppLifecycleState.resumed) {
      LuckyRoomSvgaFlagsStore.invalidate();
      unawaited(LuckyRoomSvgaFlagsStore.load(force: true));
      unawaited(_sharedAudioSync.reassertPlaybackOutput());
      if (_mySeatIndex != null) {
        _scheduleVoiceHeal('app_resumed');
      } else if (_useOrbitVoice) {
        _scheduleOrbitHearingHeal('app_resumed');
      }
    }
  }

  void _scheduleEntranceProfileEarlyExit() {
    _entranceTimer?.cancel();
  }

  void _resetEntranceMediaGate() {
    _entranceMediaReady = false;
    _entrancePlaybackStarted = false;
    _entrancePattiLoaded = _activePattiSvga == null;
    _entranceCarLoaded = _activeCarSvga == null;
  }

  void _onEntranceCarLoaded() {
    if (!_isEntranceAnimating || _entranceCarLoaded) return;
    _entranceCarLoaded = true;
    _tryStartEntrancePlayback();
  }

  void _onEntrancePattiLoaded() {
    if (!_isEntranceAnimating || _entrancePattiLoaded) return;
    _entrancePattiLoaded = true;
    _tryStartEntrancePlayback();
  }

  void _tryStartEntrancePlayback() {
    if (!_isEntranceAnimating || _entrancePlaybackStarted) return;
    if (!_entranceCarLoaded || !_entrancePattiLoaded) return;
    if (!mounted) return;

    _entrancePlaybackStarted = true;
    _entranceMediaReady = true;
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isEntranceAnimating) return;

      _entranceCarSvgaKey.currentState?.syncDurationTo(
        _entranceAnimationDuration,
      );
      _entrancePattiSvgaKey.currentState?.syncDurationTo(
        _entranceAnimationDuration,
      );
      _entranceCarSvgaKey.currentState?.play();
      _entrancePattiSvgaKey.currentState?.play();

      _entranceController!.reset();
      _scheduleEntranceProfileEarlyExit();
      _entranceController!.forward().then((_) {
        _entranceTimer?.cancel();
        _releaseEntrancePattiGate();
        if (mounted) {
          setState(() {
            _enteringUser = null;
            _activePattiSvga = null;
            _activeCarSvga = null;
            _activePattiUrl = null;
            _isEntranceAnimating = false;
            _entranceMediaReady = false;
            _entrancePlaybackStarted = false;
          });
        } else {
          _isEntranceAnimating = false;
          _entrancePlaybackStarted = false;
        }
      });
    });
  }

  void _releaseEntrancePattiGate() {
    final token = _entranceGateToken;
    _entranceGateToken = null;
    if (token == null) return;
    try {
      ref.read(pattiPlaybackGateProvider.notifier).release(token);
    } catch (e) {
      debugPrint('[Entrance] gate release failed: $e');
    }
  }

  Future<void> _armEntranceAnimation({
    required Map<String, dynamic> userProfile,
    String? carSvga,
    String? pattiSvga,
    String? pattiUrl,
  }) async {
    final gate = ref.read(pattiPlaybackGateProvider.notifier);
    late final String token;
    try {
      token = await gate.acquire(PattiKind.entrance);
    } catch (e) {
      debugPrint('[Entrance] gate acquire failed: $e');
      return;
    }
    if (!mounted) {
      gate.release(token);
      return;
    }
    if (_isEntranceAnimating) {
      gate.release(token);
      debugPrint('[Entrance] arm skip already animating');
      return;
    }

    _entranceGateToken = token;

    final resolvedPatti = MediaUrlUtil.resolveEntrancePatti(
      imageUrl: pattiUrl,
      svgaUrl: pattiSvga,
    );
    final resolvedCar = MediaUrlUtil.nullableMediaUrl(carSvga);

    final uid = _normalizePresenceUserId(userProfile['id']);
    if (uid != null) {
      _pruneEntranceLastShownAt();
      _entranceLastShownAt[uid] = DateTime.now();
    }
    debugPrint(
      '[Entrance] ARM uid=$uid user=${userProfile['username']} '
      'car=${resolvedCar != null} pattiSvga=${resolvedPatti.svgaUrl != null} '
      'pattiImg=${resolvedPatti.imageUrl != null}',
    );
    _isEntranceAnimating = true;
    _entrancePlaybackToken++;
    _entrancePattiSvgaKey = GlobalKey<RaveSVGAPlayerState>();
    _entranceCarSvgaKey = GlobalKey<RaveSVGAPlayerState>();
    setState(() {
      _enteringUser = userProfile;
      _activeCarSvga = resolvedCar;
      _activePattiSvga = resolvedPatti.svgaUrl;
      _activePattiUrl = resolvedPatti.imageUrl;
      _resetEntranceMediaGate();
    });

    if (_entrancePattiLoaded && _entranceCarLoaded) {
      _tryStartEntrancePlayback();
    } else {
      final playbackToken = _entrancePlaybackToken;
      Future<void>.delayed(const Duration(seconds: 10), () {
        if (!mounted ||
            !_isEntranceAnimating ||
            _entrancePlaybackStarted ||
            playbackToken != _entrancePlaybackToken) {
          return;
        }
        debugPrint('[Entrance] media timeout — start without full load');
        _entrancePattiLoaded = true;
        _entranceCarLoaded = true;
        _tryStartEntrancePlayback();
      });
    }
  }

  Future<void> _triggerEntranceShow(String userId, String username) async {
    final uid = _normalizePresenceUserId(userId);
    if (uid == null) return;

    final selfId = _normalizePresenceUserId(
      ref.read(userProfileProvider).value?['id'] ??
          Supabase.instance.client.auth.currentUser?.id,
    );
    if (_resumingMinimizedSession && selfId != null && uid == selfId) {
      _entranceHandledUserIds.add(uid);
      debugPrint('[Entrance] trigger blocked minimize-resume self $username');
      return;
    }

    if (_entranceHandledUserIds.contains(uid) ||
        _entranceInFlight.contains(uid)) {
      debugPrint(
        '[Entrance] trigger skip $username ($uid) '
        'handled=${_entranceHandledUserIds.contains(uid)} '
        'inFlight=${_entranceInFlight.contains(uid)}',
      );
      return;
    }

    _entranceInFlight.add(uid);
    _entranceHandledUserIds.add(uid);

    try {
      debugPrint('[Entrance] trigger fetch+show $username ($uid)');

      final userProfileRes = await Supabase.instance.client
          .from('users')
          .select(
            'id, username, avatar_url, vip_level, wealth_level, user_level',
          )
          .eq('id', uid)
          .single();

      final entrance = await ref.read(userBestEntranceProvider(uid).future);
      final carSvga = MediaUrlUtil.nullableMediaUrl(entrance.carSvga);
      final resolvedPatti = MediaUrlUtil.resolveEntrancePatti(
        imageUrl: entrance.pattiUrl,
        svgaUrl: entrance.pattiSvga,
      );
      final pattiSvga = resolvedPatti.svgaUrl;
      final pattiUrl = resolvedPatti.imageUrl;

      debugPrint(
        '[Entrance] assets $username car=$carSvga patti=$pattiSvga url=$pattiUrl',
      );

      if (!mounted) return;

      if (carSvga == null && pattiSvga == null && pattiUrl == null) {
        debugPrint(
          '[Entrance] no assets $username — skip show (still handled)',
        );
        return;
      }

      unawaited(
        _broadcastEntrance(
          userId: uid,
          username: username,
          userProfile: Map<String, dynamic>.from(userProfileRes),
          carSvga: carSvga,
          pattiSvga: pattiSvga,
          pattiUrl: pattiUrl,
        ),
      );

      if (_isEntranceAnimating) {
        debugPrint('[Entrance] animation busy, wait via gate $username');
      }

      await _armEntranceAnimation(
        userProfile: Map<String, dynamic>.from(userProfileRes),
        carSvga: carSvga,
        pattiSvga: pattiSvga,
        pattiUrl: pattiUrl,
      );
    } catch (e) {
      debugPrint('[Entrance] trigger error: $e');
      _releaseEntrancePattiGate();
      _isEntranceAnimating = false;
      _entrancePlaybackStarted = false;
    } finally {
      _entranceInFlight.remove(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    RoomFloatingBubbleService.micMuted = _isMuted;

    ref.watch(luckyBonusMultiplierSvgasProvider);
    ref.watch(luckyRoomSvgaFlagsProvider);
    ref.watch(myBusinessStaffProvider);

    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(roomInvitationProvider, (
      previous,
      next,
    ) {
      if (!next.hasValue || next.value!.isEmpty) return;
      final roomId = widget.room['id'].toString();

      for (final inv in next.value!) {
        if (inv['role']?.toString() != 'seat') continue;
        if (inv['room_id']?.toString() != roomId) continue;

        final id = inv['id']?.toString();
        if (id == null || _shownSeatInviteIds.contains(id)) continue;

        _shownSeatInviteIds.add(id);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await openRoomSeatInviteAcceptScreen(
            context,
            invitation: inv,
            navigateToRoomOnAccept: false,
            onAcceptedInRoom: () {
              unawaited(_onSeatInviteAcceptedInRoom());
            },
          );
          _shownSeatInviteIds.remove(id);
        });
        break;
      }
    });

    return PopScope(
      canPop: _canPopRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showExitSidebar) {
          _closeExitSidebar(force: true);
        } else {
          _openExitSidebar();
        }
      },
      child: RoomMicEmojiOverlayManager(
        controller: _micEmojiOverlayController,
        child: GiftFlightManager(
          controller: _giftFlightController,
          onFullScreenSvga: _showFullScreenGift,
          child: Scaffold(
            backgroundColor: roomBackdropColor,
            body: Stack(
              children: [
                Positioned.fill(
                  child: _hasCustomBackground
                      ? RoomBackgroundMedia(
                          url: _roomData!['background_url'].toString(),
                          fit: BoxFit.cover,
                          darkenAlpha: 0,
                        )
                      : const RoomDefaultBackground(
                          fit: BoxFit.cover,
                          darkenAlpha: 0,
                        ),
                ),

                if (_showReconnectBanner)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 52,
                    left: 0,
                    right: 0,
                    child: Center(child: _buildReconnectBanner()),
                  ),

                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildHeaderChipsRow(),
                      if (!_showExitSidebar)
                        RoomYoutubePlayerHost(controller: _youtubeSync),

                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Consumer(
                                builder: (context, ref, _) {
                                  final roomId = widget.room['id'].toString();
                                  final session = ref
                                      .watch(roomPkSessionProvider(roomId))
                                      .valueOrNull;
                                  final onRefresh = () {
                                    _fetchRoomDetails();
                                    _fetchSeats();
                                  };
                                  if (session?.isSolo == true) {
                                    return PkOverlay(
                                      roomId: roomId,
                                      canManage: _canManageRoom,
                                      onRefreshRoom: onRefresh,
                                      playerA: _seatUserAt(0),
                                      playerB: _seatUserAt(1),
                                    );
                                  }
                                  return TeamPkOverlay(
                                    roomId: roomId,
                                    canManage: _canManageRoom,
                                    onRefreshRoom: onRefresh,
                                  );
                                },
                              ),
                              _buildSeatsGrid(),
                              ListenableBuilder(
                                listenable: _chatListVersion,
                                builder: (context, _) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildChatTabs(),
                                      _buildRoomAnnouncementBar(),
                                      _buildChatArea(),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildBottomToolbar(),
                    ],
                  ),
                ),

                if (_mentionQuery != null && _mentionSuggestions.isNotEmpty)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: MediaQuery.paddingOf(context).bottom + 72,
                    child: _buildMentionSuggestions(),
                  ),

                Positioned(
                  right: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 68,
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_chatBarOpen, _gamesRev]),
                    builder: (context, _) {
                      if (_chatBarOpen.value) return const SizedBox.shrink();
                      return RoomSideFloatRail(
                        roomId: widget.room['id'].toString(),
                        activeGames: _activeGames,
                        onGameTap: _launchGameFromConfig,
                      );
                    },
                  ),
                ),
                ListenableBuilder(
                  listenable: _chatBarOpen,
                  builder: (context, _) {
                    if (_chatBarOpen.value) return const SizedBox.shrink();
                    return RoomSharedAudioFloatingPlayer(
                    sync: _sharedAudioSync,
                    queue: _sharedAudioQueue,
                    bottomInset: 72 + (_repeatGiftSession != null ? 48 : 0),
                    onOpenLibrary: _canUseRoomAudio
                        ? () {
                            RoomSharedAudioSheet.show(
                              context,
                              controller: _sharedAudioSync,
                              queue: _sharedAudioQueue,
                              roomId: widget.room['id'].toString(),
                            );
                          }
                        : null,
                  );
                  },
                ),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _chatBarOpen,
                    _repeatComboTick,
                  ]),
                  builder: (context, _) {
                    if (_chatBarOpen.value || _repeatGiftSession == null) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.of(context).padding.bottom + 72,
                      child: Center(child: _buildRepeatGiftFloatingButton()),
                    );
                  },
                ),

                if (_isEntranceAnimating && _activeCarSvga != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: _entranceMediaReady ? 1 : 0,
                        child: RaveSVGAPlayer(
                          key: _entranceCarSvgaKey,
                          resUrl: _activeCarSvga!,
                          fit: BoxFit.contain,
                          repeat: false,
                          autoPlay: false,
                          onLoaded: _onEntranceCarLoaded,
                        ),
                      ),
                    ),
                  ),

                if (_isEntranceAnimating) _buildEntranceOverlay(),

                if (_bonusPatti != null)
                  RoomBonusPattiOverlay(
                    key: ValueKey('bonus_patti_${_bonusPatti!.senderId}'),
                    data: _bonusPatti!,
                    visible: _bonusPattiVisible,
                    onDismissed: _onBonusPattiDismissed,
                  ),
                ..._activeLuckyFanbis.map((item) {
                  final id = item['id']?.toString() ?? '';
                  final stackY = (item['stackY'] as num?)?.toDouble() ?? 0;
                  return RoomLuckyProWinOverlay(
                    key: ValueKey('fanbi_$id'),
                    username: item['username']?.toString() ?? 'User',
                    avatarUrl: item['avatarUrl']?.toString(),
                    rewardCoins: (item['rewardCoins'] as num?)?.toInt() ?? 0,
                    stackOffsetY: stackY,
                    onFinished: () => _removeLuckyFanbi(id),
                  );
                }),
                ..._activeLuckyMultipliers.map((item) {
                  final id = item['id']?.toString() ?? '';
                  final svgaUrl = item['svgaUrl']?.toString() ?? '';
                  if (svgaUrl.isEmpty) return const SizedBox.shrink();
                  final stackY = (item['stackY'] as num?)?.toDouble() ?? 0;
                  return RoomBonusMultiplierSvgaOverlay(
                    key: ValueKey('mult_$id'),
                    svgaUrl: svgaUrl,
                    stackOffsetY: stackY,
                    onFinished: () => _removeLuckyMultiplier(id),
                  );
                }),

                Positioned(
                  top: MediaQuery.paddingOf(context).top + 52,
                  left: 0,
                  right: 0,
                  child: LuckyBagRoomOverlay(
                    roomId: widget.room['id'].toString(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _seatGridHeightEstimate(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final layout = _resolveRoomMicLayout();
    final columns = layout.maxColumns;
    const hPad = 32.0;
    const crossSpacing = 4.0;
    const mainSpacing = 4.0;
    final contentHeight = _seatContentHeight(context, layout);
    final gridWidth = width - hPad;
    final cellWidth = (gridWidth - (columns - 1) * crossSpacing) / columns;
    final aspectRatio = (cellWidth / contentHeight).clamp(0.62, 0.92);
    final cellHeight = (cellWidth / aspectRatio) < contentHeight
        ? contentHeight
        : cellWidth / aspectRatio;
    final rows = layout.rows.length;
    return 4.0 + rows * cellHeight + (rows - 1) * mainSpacing;
  }

  double _headerBlockHeight(BuildContext context) {
    const headerContent = 62.0 + 2 + 22 + 12;
    final youtubeH = _youtubeSync.isPlayerVisible
        ? 16 + (MediaQuery.sizeOf(context).width - 32) * 9 / 16
        : 0.0;
    return MediaQuery.paddingOf(context).top + 2 + headerContent + youtubeH;
  }

  double _entranceSlideTop(BuildContext context) {
    final box = _seatsGridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final seatBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      return seatBottom - _entranceBannerHeight * 0.72;
    }
    return _headerBlockHeight(context) +
        _seatGridHeightEstimate(context) -
        _entranceBannerHeight * 0.72;
  }

  Widget _buildEntranceOverlay() {
    if (_enteringUser == null) return const SizedBox.shrink();

    final username = _enteringUser!['username'] ?? 'User';
    final avatarUrl = _enteringUser!['avatar_url'];
    final userId = _enteringUser!['id'];

    if (userId == null) return const SizedBox.shrink();

    final badgesAsync = ref.watch(userBadgesProvider(userId));
    final hasSvgaPatti = _activePattiSvga != null;
    final bannerH = hasSvgaPatti ? 120.0 : _entranceBannerHeight;
    final top = _entranceSlideTop(context) - (hasSvgaPatti ? 12.0 : 0.0);

    return Positioned(
      top: top,
      right: 0,
      width: MediaQuery.of(context).size.width,
      height: bannerH,
      child: IgnorePointer(
        child: Opacity(
          opacity: _entranceMediaReady ? 1 : 0,
          child: SlideTransition(
            position: _entranceSlideAnimation!,
            child: FadeTransition(
              opacity: _entranceFadeAnimation!,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (hasSvgaPatti)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: RaveSVGAPlayer(
                          key: _entrancePattiSvgaKey,
                          resUrl: _activePattiSvga!,
                          fit: BoxFit.contain,
                          repeat: false,
                          autoPlay: false,
                          onLoaded: _onEntrancePattiLoaded,
                        ),
                      ),
                    )
                  else if (_activePattiUrl != null)
                    Positioned.fill(
                      child: AppNetworkImage(
                        imageUrl: _activePattiUrl!,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                        transformWidth: 1200,
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: _entranceProfileLeftInset,
                      top: hasSvgaPatti
                          ? _entranceProfileTopInsetSvga
                          : _entranceProfileTopInsetImage,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: _entranceProfileSize,
                          height: _entranceProfileSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFD700),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFD700,
                                ).withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              _entranceProfileSize / 2,
                            ),
                            child: avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Icon(
                                      Icons.person,
                                      color: Colors.white24,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: Colors.white54,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // The banner is a fixed height, so the name and badges
                        // have to fit the room left beside the avatar. Without
                        // a width bound the badge row ran past the banner and
                        // smeared across the title artwork behind it.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width -
                                _entranceProfileLeftInset -
                                _entranceProfileSize -
                                28,
                          ),
                          child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            badgesAsync.when(
                              data: (badges) {
                                if (badges.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                // One clipped line. A Wrap here spilled onto
                                // a second row inside a banner that has no
                                // height for it, which is what put badges on
                                // top of the user's title.
                                return SizedBox(
                                  height: 16,
                                  child: ClipRect(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        for (final badge in badges.take(4))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            child: UserBadgeChip(badge: badge),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              loading: () => const SizedBox(height: 14),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExitSidebar(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _closeExitSidebar(force: true),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.65,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF150826).withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                  ),
                  border: Border(
                    left: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSidebarCircleButton(
                          icon: Icons.zoom_in_map,
                          label: context.l10n.room_minimize,
                          onTap: _minimizeRoomFromSidebar,
                        ),
                        _buildSidebarCircleButton(
                          icon: Icons.power_settings_new,
                          label: context.l10n.room_close,
                          color: Colors.redAccent,
                          onTap: _exitRoomFromSidebar,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'More activities',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final activeRooms = ref.watch(activeRoomsProvider);
                          return activeRooms.when(
                            data: (rooms) {
                              final otherRooms = rooms
                                  .where((r) => r['id'] != widget.room['id'])
                                  .toList();
                              if (otherRooms.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No other active rooms',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      decoration: TextDecoration.none,
                                      height: 1.2,
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: otherRooms.length,
                                itemBuilder: (context, index) {
                                  return _buildSidebarRoomCard(
                                    otherRooms[index],
                                  );
                                },
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFFD700),
                              ),
                            ),
                            error: (_, __) => const Center(
                              child: Text(
                                'Failed to load rooms',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  decoration: TextDecoration.none,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarCircleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFFFFD700),
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarRoomCard(Map<String, dynamic> room) {
    final title = room['title'] ?? 'Room';
    final hostName = room['host_name'] ?? 'Host';
    final viewers = room['online_users_count'] ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (_sidebarActionInProgress) return;
          _sidebarActionInProgress = true;
          try {
            _removeExitSidebarOverlay();
            final myId = Supabase.instance.client.auth.currentUser?.id;
            unawaited(RoomFloatingBubbleService.hideRoomBubble());
            try {
              await RoomLiveScreen.cleanupRoomStatic(
                widget.room['id'],
                myId,
              ).timeout(const Duration(seconds: 10));
            } catch (e) {
              debugPrint('[ROOM] switch cleanup: $e');
            }
            clearActiveRoomState(ref);

            if (mounted) {
              await openRoomLive(
                context,
                Map<String, dynamic>.from(room),
                replace: true,
              );
            }
          } finally {
            _sidebarActionInProgress = false;
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            image: room['image_url'] != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(room['image_url']),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.5),
                      BlendMode.darken,
                    ),
                  )
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                if (room['image_url'] == null)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2D1B4E), Color(0xFF1A0A2E)],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  left: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          decoration: TextDecoration.none,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hostName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                decoration: TextDecoration.none,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.graphic_eq,
                                  color: Colors.greenAccent,
                                  size: 8,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '$viewers',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchRoomLevelStats() async {
    if (_roomData?['room_stats'] != null || widget.room['room_stats'] != null) {
      return;
    }
    try {
      final stats = await Supabase.instance.client
          .from('room_stats')
          .select('current_level')
          .eq('room_id', widget.room['id'])
          .maybeSingle();
      if (!mounted || stats == null) return;
      setState(() {
        _roomData ??= Map<String, dynamic>.from(widget.room);
        _roomData!['room_stats'] = stats;
      });
    } catch (e) {
      debugPrint('Room level fetch error: $e');
    }
  }

  void _showRoomAnnouncement() {
    final announcement = _roomAnnouncementText();
    final roomTitle = widget.room['title'] ?? _roomData?['title'] ?? 'Room';
    final dialogWidth = MediaQuery.sizeOf(context).width * 0.88;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: dialogWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Iconsax.document_text,
                        color: Colors.amber,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Room Announcement',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            roomTitle,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 120),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    announcement.isNotEmpty
                        ? announcement
                        : 'No announcement set for this room.',
                    style: TextStyle(
                      color: announcement.isNotEmpty
                          ? Colors.white70
                          : Colors.white38,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.amber.withValues(alpha: 0.15),
                      foregroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRoomRankingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const GiftCenterScreen(initialPage: 2, initialPeriod: 'Day'),
      ),
    );
  }

  void _showYoutubeSearchDialog() {
    final state = _roomData?['youtube_state'];
    final bool isAlreadyActive = state?['is_active'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => RoomYoutubePickerSheet(
        isPartyActive: isAlreadyActive,
        onPlayVideo: (videoId) async {
          Navigator.pop(sheetContext);
          try {
            await _youtubeSync.playVideo(videoId);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.room_couldNotStartYoutube('$e')),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        },
        onStopParty: () async {
          Navigator.pop(sheetContext);
          try {
            await _youtubeSync.stopParty();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.room_couldNotStopYoutube('$e')),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildHeader() {
    final rawTitle = (widget.room['title'] ?? _roomData?['title'] ?? 'Room')
        .toString();
    final roomTitle = rawTitle.length <= 13
        ? rawTitle
        : '${rawTitle.substring(0, 13)}…';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            RoomDetailsSheet(room: _roomData ?? widget.room),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 11, 10, 11),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundImage:
                                (widget.room['image_url'] ??
                                        _roomData?['image_url']) !=
                                    null
                                ? AppNetworkImageProvider(
                                    widget.room['image_url'] ??
                                        _roomData!['image_url'],
                                    transformWidth: 96,
                                    transformHeight: 96,
                                  )
                                : null,
                            child:
                                (widget.room['image_url'] ??
                                        _roomData?['image_url']) ==
                                    null
                                ? const Icon(
                                    Icons.meeting_room,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  roomTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 19,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'ID: ${roomPublicId(Map<String, dynamic>.from(_roomData ?? widget.room))}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 8,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _openRoomRankingScreen,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Image.asset(
                      'assets/home/tabs/cup.webp',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _showShareRoomSheet,
                child: const Icon(
                  Icons.share_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openExitSidebar,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Image.asset(
                    'assets/home/tabs/room-turn.webp',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChipsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_showRoomSpending) ...[
            RoomContributionStrip(
              roomId: widget.room['id'].toString(),
              onTap: () => RoomContributionSheet.show(
                context,
                ref: ref,
                roomId: widget.room['id'].toString(),
              ),
            ),
            const SizedBox(width: 4),
          ],
          _buildHeaderOnlineMembers(),
        ],
      ),
    );
  }

  Widget _buildHeaderOnlineMembers() {
    final seatedCount = _seats.where((s) {
      final id = s['user_id']?.toString();
      return id != null && id.isNotEmpty;
    }).length;
    final firstOnline = _onlineUsers.isEmpty ? null : _onlineUsers.first;

    return GestureDetector(
      key: _audienceKey,
      onTap: _showOnlineMembersSheet,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: firstOnline == null
                  ? const Icon(Icons.group, color: Colors.white24, size: 13)
                  : Builder(
                      builder: (context) {
                        final id = firstOnline['id']?.toString();
                        final avatar = _buildOnlineAvatar(
                          firstOnline['avatar_url'],
                          size: 18,
                        );
                        if (id == null || id.isEmpty) return avatar;
                        return KeyedSubtree(
                          key: _anchorKeyFor(id),
                          child: avatar,
                        );
                      },
                    ),
            ),
            const SizedBox(width: 3),
            Text(
              '$seatedCount/${_onlineUsers.length}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 1),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 12,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  void _invalidateRoomContributions() {
    // Intentionally empty on the gift hot path. Refetching contribution
    // rankings on every gift was 2 RPCs + users.inFilter per send and made
    // busy rooms feel like every tap waited on loading. Rankings refresh when
    // the contribution sheet opens.
  }

  Widget _buildOnlineAvatar(String? url, {double size = 25}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70, width: 1),
        color: Colors.grey[900],
      ),
      child: ClipOval(
        child: url != null
            ? AppNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                transformWidth: 64,
                transformHeight: 64,
              )
            : Icon(Icons.person, size: size * 0.6, color: Colors.white24),
      ),
    );
  }

  Widget _buildSeatAvatar(String? url) {
    if (url == null || url.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF2A2A3A),
        child: Icon(Icons.person, color: Colors.white54, size: 26),
      );
    }
    return AppNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      transformWidth: 160,
      transformHeight: 160,
      memCacheWidth: 160,
      memCacheHeight: 160,
      errorWidget: (_, _, _) => const ColoredBox(
        color: Color(0xFF2A2A3A),
        child: Icon(Icons.person, color: Colors.white54, size: 26),
      ),
    );
  }

  void _showShareRoomSheet() {
    final room = _roomData ?? widget.room;
    final host = ref.read(userProfileProvider).value;
    final hostUsername = host?['username'] ?? 'Host';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          RoomShareToChatSheet(room: room, hostUsername: hostUsername),
    );
  }

  void _showOnlineMembersSheet() => _showRoomMembersSheet();

  Widget _buildRoomMemberSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.black54, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomMemberAvatar(String userId, String? avatarUrl) {
    return UserFramedAvatar(userId: userId, avatarUrl: avatarUrl, radius: 18);
  }

  Widget _buildRoomMemberBadgesRow(String userId) {
    return UserMemberBadgesRow(userId: userId);
  }

  Widget _buildRoomMemberTile({
    required BuildContext sheetContext,
    required Map<String, dynamic> user,
    required String subtitle,
    IconData? badgeIcon,
    Color? badgeColor,
    int? seatIndex,
  }) {
    final userId = user['id']?.toString() ?? '';
    final username = user['username'] ?? 'User';
    final avatarUrl = user['avatar_url'] as String?;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _buildRoomMemberAvatar(userId, avatarUrl),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            username,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          _buildRoomMemberBadgesRow(userId),
        ],
      ),
      subtitle: Row(
        children: [
          if (badgeIcon != null) ...[
            Icon(badgeIcon, size: 12, color: badgeColor ?? Colors.black54),
            const SizedBox(width: 4),
          ],
          Text(
            subtitle,
            style: TextStyle(
              color: badgeColor == Colors.white54
                  ? Colors.black54
                  : (badgeColor ?? Colors.black54),
              fontSize: 11,
            ),
          ),
        ],
      ),
      trailing: userId.isEmpty
          ? null
          : _buildMemberQuickActions(
              sheetContext: sheetContext,
              userId: userId,
              username: username,
              avatarUrl: avatarUrl,
              seatIndex: seatIndex,
            ),
      onTap: userId.isEmpty
          ? null
          : () {
              Navigator.pop(sheetContext);
              _showMemberActionsSheet(
                userId: userId,
                username: username,
                avatarUrl: avatarUrl,
                seatIndex: seatIndex,
              );
            },
    );
  }

  void _showRoomMembersSheet() {
    RoomMembersSheet.show(
      context,
      ref: ref,
      roomId: widget.room['id'].toString(),
      hostId: widget.room['host_id']?.toString(),
      onlineUsers: _onlineUsers,
      seatIndexForUser: (userId) {
        for (var i = 0; i < _seats.length; i++) {
          if (_seats[i]['user_id']?.toString() == userId) return i;
        }
        return null;
      },
      onMemberTap: (userId, username, avatarUrl, seatIndex) {
        _showMemberActionsSheet(
          userId: userId,
          username: username,
          avatarUrl: avatarUrl,
          seatIndex: seatIndex,
        );
      },
    );
  }

  int _seatCrossAxisCount(int micCount) {
    return _resolveRoomMicLayout(micCount: micCount).maxColumns;
  }

  double _seatScaleFor(_RoomMicLayout layout, int index) {
    if (layout.id == 'owner_1_n') {
      return layout.ownerSeatIndex == index
          ? _kOwnerModeHostScale
          : _kOwnerModeGuestScale;
    }
    if (layout.id == 'classic_8') return _kClassic8Scale;
    return 1.0;
  }

  double _seatBandHeight(_RoomMicLayout layout) {
    final maxScale = switch (layout.id) {
      'owner_1_n' =>
        _kOwnerModeHostScale > _kOwnerModeGuestScale
            ? _kOwnerModeHostScale
            : _kOwnerModeGuestScale,
      'classic_8' => _kClassic8Scale,
      _ => 1.0,
    };
    return _kSeatBand * maxScale;
  }

  double _seatLabelBlockHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    const gap = 1.0;
    const safety = 2.0;
    final username = scaler.scale(9);
    final charmText = scaler.scale(7);
    final charmRow = charmText > 8 ? charmText : 8.0;
    return gap + username + 3 + charmRow + safety;
  }

  double _seatContentHeight(BuildContext context, _RoomMicLayout layout) {
    return _seatBandHeight(layout) + _seatLabelBlockHeight(context);
  }

  List<_RoomMicLayout> get _roomMicLayouts => const [
    _RoomMicLayout(
      id: 'classic_8',
      micCount: 8,
      rows: [4, 4],
      title: '8 mics',
      subtitle: 'Classic free seats',
    ),
    _RoomMicLayout(
      id: 'classic_10',
      micCount: 10,
      rows: [5, 5],
      title: '10 mics',
      subtitle: 'Classic free seats',
    ),
    _RoomMicLayout(
      id: 'owner_8_1',
      micCount: 9,
      rows: [1, 4, 4],
      ownerSeatIndex: 0,
      title: '8+1 mics',
      subtitle: 'Owner + eight seats',
    ),
    _RoomMicLayout(
      id: 'stage_4_4_1',
      micCount: 9,
      rows: [1, 4, 4],
      ownerSeatIndex: 0,
      title: '4+4+1 mics',
      subtitle: 'Stage split seats',
    ),
    _RoomMicLayout(
      id: 'owner_1_n',
      micCount: 12,
      rows: [1, 5, 6],
      ownerSeatIndex: 0,
      title: '1+n mics',
      subtitle: 'Flexible owner mode',
    ),
    _RoomMicLayout(
      id: 'classic_15',
      micCount: 15,
      rows: [5, 5, 5],
      title: '15 mics',
      subtitle: 'Five by three layout',
    ),
    _RoomMicLayout(
      id: 'owner_15_1',
      micCount: 16,
      rows: [1, 5, 5, 5],
      ownerSeatIndex: 0,
      title: '15+1 mics',
      subtitle: 'Owner + full stage',
    ),
    _RoomMicLayout(
      id: 'classic_20',
      micCount: 20,
      rows: [5, 5, 5, 5],
      title: '20 mics',
      subtitle: 'Large party seats',
    ),
  ];

  _RoomMicLayout _resolveRoomMicLayout({int? micCount, String? partyMode}) {
    final mode =
        (partyMode ?? _roomData?['party_mode'] ?? widget.room['party_mode'])
            ?.toString();
    final count =
        micCount ??
        (_roomData?['mic_count'] ?? widget.room['mic_count'] ?? 8) as int;

    if (mode != null && mode.isNotEmpty) {
      for (final layout in _roomMicLayouts) {
        if (layout.id == mode) return layout;
      }
    }
    for (final layout in _roomMicLayouts) {
      if (layout.micCount == count && layout.ownerSeatIndex == null) {
        return layout;
      }
    }
    for (final layout in _roomMicLayouts) {
      if (layout.micCount == count) return layout;
    }
    final cols = count <= 10 ? (count / 2).ceil().clamp(4, 5) : 5;
    final rows = <int>[];
    var left = count;
    while (left > 0) {
      final take = left >= cols ? cols : left;
      rows.add(take);
      left -= take;
    }
    return _RoomMicLayout(
      id: 'legacy_$count',
      micCount: count,
      rows: rows,
      title: '$count mics',
      subtitle: 'Custom layout',
    );
  }

  Widget _buildSeatsGrid() {
    final layout = _resolveRoomMicLayout();
    final micCount = layout.micCount;
    final columns = layout.maxColumns;
    final roomId = widget.room['id'].toString();
    final pkSession = ref.watch(roomPkSessionProvider(roomId)).valueOrNull;
    final pkActive = pkSession?.isActive == true;
    final pkSolo = pkSession?.isSolo == true;
    final pkContributions = pkSession != null && pkActive
        ? ref.watch(roomPkContributionsProvider(pkSession.id)).valueOrNull ?? {}
        : const <String, int>{};

    return Container(
      key: _seatsGridKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const crossSpacing = 4.0;
          const mainSpacing = 4.0;
          final contentHeight = _seatContentHeight(context, layout);
          final cellWidth =
              (constraints.maxWidth - (columns - 1) * crossSpacing) / columns;
          final aspectRatio = (cellWidth / contentHeight).clamp(0.62, 0.92);
          final cellHeight = (cellWidth / aspectRatio) < contentHeight
              ? contentHeight
              : cellWidth / aspectRatio;
          final avatarBand = _seatBandHeight(layout);
          const cpLineW = 72.0;
          const cpLineH = 48.0;

          var seatIndex = 0;
          final rowWidgets = <Widget>[];
          final cpOverlays = <Widget>[];

          for (var r = 0; r < layout.rows.length; r++) {
            final seatsInRow = layout.rows[r];
            final rowChildren = <Widget>[];

            for (var c = 0; c < seatsInRow; c++) {
              final index = seatIndex++;
              if (c > 0) {
                rowChildren.add(const SizedBox(width: crossSpacing));
              }
              rowChildren.add(
                SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: index < _seats.length
                      ? _buildSeatTile(
                          index,
                          pkActive:
                              pkActive &&
                              (pkSolo
                                  ? (index == 0 || index == 1)
                                  : index < 10),
                          pkSolo: pkSolo,
                          pkContributions: pkContributions,
                          isOwnerSeat: layout.ownerSeatIndex == index,
                          seatScale: _seatScaleFor(layout, index),
                        )
                      : const SizedBox.shrink(),
                ),
              );

              if (c < seatsInRow - 1 &&
                  index + 1 < micCount &&
                  _areAdjacentSeatCp(index, index + 1)) {
                final left =
                    ((columns - seatsInRow) * (cellWidth + crossSpacing)) / 2 +
                    c * (cellWidth + crossSpacing) +
                    cellWidth +
                    crossSpacing / 2 -
                    cpLineW / 2;
                cpOverlays.add(
                  Positioned(
                    left: left,
                    top:
                        r * (cellHeight + mainSpacing) +
                        avatarBand / 2 -
                        cpLineH / 2,
                    width: cpLineW,
                    height: cpLineH,
                    child: const IgnorePointer(child: _SeatCpLineSvga()),
                  ),
                );
              }
            }

            if (r > 0) {
              rowWidgets.add(const SizedBox(height: mainSpacing));
            }
            rowWidgets.add(
              SizedBox(
                height: cellHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: rowChildren,
                ),
              ),
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Column(mainAxisSize: MainAxisSize.min, children: rowWidgets),
              ...cpOverlays,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSeatTile(
    int index, {
    bool pkActive = false,
    bool pkSolo = false,
    Map<String, int> pkContributions = const {},
    bool isOwnerSeat = false,
    double seatScale = 1.0,
  }) {
    final seat = _seats[index];
    final user = seat['user'];
    final pkTeamColor = pkActive
        ? (pkSolo
              ? (index == 0 ? const Color(0xFFFF5252) : const Color(0xFF448AFF))
              : (index < 5 ? const Color(0xFFFF5252) : const Color(0xFF448AFF)))
        : null;

    final band = _kSeatBand * seatScale;
    final soundWave = band * 1.66;
    final emptyCircle = 44.0 * seatScale;
    final emptyOwnerOuter = 53.0 * seatScale;
    final avatarSize = 42.0 * seatScale;

    final frameSize = 68.0 * seatScale;
    final micIcon = 24.0 * seatScale;
    final lockIcon = 14.0 * seatScale;
    final chairFallback = 25.0 * seatScale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: band,
          height: band,
          child: OverflowBox(
            maxWidth: soundWave,
            maxHeight: soundWave,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (user != null)
                  ValueListenableBuilder<int>(
                    valueListenable: _soundLevelsVersion,
                    builder: (context, _, __) {
                      final uid = user['id']?.toString() ?? '';
                      final pulsing = _hasSharedAudioSeatPulse(uid);
                      final micOpen = seat['is_muted'] != true;

                      if (!micOpen && !pulsing) {
                        return const SizedBox.shrink();
                      }
                      final level = _seatSoundLevelForUser(uid);
                      return IgnorePointer(
                        child: _SeatSoundWaves(
                          isActive: _isSeatSpeaking(uid) || pulsing,
                          soundLevel: level,
                          forceLoud: pulsing,
                          micOpen: micOpen,
                          size: soundWave,
                        ),
                      );
                    },
                  ),
                SizedBox(
                  width: band,
                  height: band,
                  child: Stack(
                    key: _seatKeys[index],
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (user == null)
                        SizedBox(
                          width: isOwnerSeat ? emptyOwnerOuter : emptyCircle,
                          height: isOwnerSeat ? emptyOwnerOuter : emptyCircle,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: emptyCircle,
                                height: emptyCircle,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.32),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: seat['is_locked'] == true
                                      ? Icon(
                                          Icons.lock_rounded,
                                          color: Colors.amber.shade700,
                                          size: lockIcon,
                                        )
                                      : isOwnerSeat
                                      ? Transform.scale(
                                          scale: 1.22,
                                          child: Image.asset(
                                            'assets/room/owner_chair_crown.webp',
                                            width: emptyCircle,
                                            height: emptyCircle,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high,
                                            errorBuilder: (_, __, ___) => Icon(
                                              Icons.event_seat_rounded,
                                              color: Colors.white,
                                              size: chairFallback,
                                            ),
                                          ),
                                        )
                                      : SvgPicture.asset(
                                          'assets/room/seat_mic_white.svg',
                                          width: micIcon,
                                          height: micIcon,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (user != null && pkTeamColor != null)
                        Container(
                          width: band,
                          height: band,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: pkTeamColor, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: pkTeamColor.withValues(alpha: 0.45),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      GestureDetector(
                        onTap: () {
                          if (user != null) {
                            _handleOccupiedSeatTap(index);
                          } else {
                            _handleSeatTap(index);
                          }
                        },
                        onLongPress: user == null
                            ? null
                            : () => _showOccupiedSeatMiniProfile(index),
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            color: user != null
                                ? Colors.transparent
                                : Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            boxShadow: user != null
                                ? [
                                    const BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipOval(
                            child: user != null
                                ? _buildSeatAvatar(
                                    user['avatar_url'] as String?,
                                  )
                                : Container(),
                          ),
                        ),
                      ),
                      if (user != null)
                        Consumer(
                          builder: (context, ref, child) {
                            final userId = user['id'];
                            if (userId == null) return const SizedBox.shrink();

                            final frameAsync = ref.watch(
                              userEquippedFrameProvider(userId),
                            );

                            return frameAsync.when(
                              data: (frame) {
                                if (frame == null)
                                  return const SizedBox.shrink();
                                final imageUrl = frame['image_url'];
                                final svgaUrl = frame['svga_url'];

                                if (imageUrl == null && svgaUrl == null) {
                                  return const SizedBox.shrink();
                                }

                                return IgnorePointer(
                                  child: SizedBox(
                                    width: frameSize,
                                    height: frameSize,
                                    child: DeferredSeatFrame(
                                      imageUrl: imageUrl?.toString(),
                                      svgaUrl: svgaUrl?.toString(),
                                      memCacheWidth: 180,
                                    ),
                                  ),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                            );
                          },
                        ),
                      if (user != null)
                        Positioned(
                          bottom: -1,
                          right: -1,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _soundLevelsVersion,
                            builder: (context, _, __) => _buildSeatMicIndicator(
                              user['id'],
                              seat['is_muted'] == true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          user != null
              ? user['username']
              : (seat['is_locked'] == true ? 'Locked' : 'No.${index + 1}'),
          style: TextStyle(
            color: user != null
                ? Colors.white
                : (seat['is_locked'] == true ? Colors.amber : Colors.white38),
            fontSize: 9,
            height: 1.0,
            fontWeight: user != null ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (user != null)
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, color: Color(0xFFFF4081), size: 8),
                const SizedBox(width: 2),
                Text(
                  NumberFormatter.format(
                    user != null && user['id'] != null
                        ? (pkActive
                              ? (pkContributions[user['id']?.toString() ??
                                        ''] ??
                                    0)
                              : (_seatGiftTotals[user['id']] ?? 0))
                        : 0,
                  ).toLowerCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    height: 1.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleSeatTap(int index) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    final seat = _seats[index];
    final isOccupied = seat['user_id'] != null;
    final isMe = seat['user_id'] == user['id'];
    final bool canManage = _canManageRoom;
    final bool isLocked = seat['is_locked'] == true;
    final peerProtected = isOccupied && !isMe
        ? await _isSuperAdminPeerProtected(seat['user_id'].toString())
        : false;

    final targetUserId = isOccupied ? seat['user_id']?.toString() : null;
    final isTargetHost = targetUserId != null && targetUserId == _roomHostId;
    String targetRole = 'member';
    if (isOccupied &&
        !isMe &&
        !isTargetHost &&
        (_canInviteRoomAdmin || _isRoomHost)) {
      targetRole = await _fetchRoomMemberRole(targetUserId!);
    }
    final username = seat['user']?['username']?.toString() ?? 'User';
    final showMakeAdmin =
        isOccupied &&
        !isMe &&
        !isTargetHost &&
        _canInviteRoomAdmin &&
        targetRole == 'member';
    final showRemoveAdmin =
        isOccupied &&
        !isMe &&
        !isTargetHost &&
        _isRoomHost &&
        targetRole == 'admin';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            if (!isOccupied) ...[
              _buildSeatOption(
                icon: isLocked ? Iconsax.unlock : Iconsax.lock,
                title: isLocked ? 'Unlock Seat' : 'Lock Seat',
                onTap: !canManage
                    ? null
                    : () {
                        Navigator.pop(context);
                        _toggleSeatLock(index);
                      },
                color: !canManage ? Colors.white24 : null,
              ),
              if (!isLocked || _canSitOnLockedSeat)
                _buildSeatOption(
                  icon: Iconsax.user_add,
                  title: _mySeatIndex == null
                      ? (isLocked && _canSitOnLockedSeat
                            ? 'Take Seat (Super Admin)'
                            : context.l10n.room_takeMic)
                      : 'Move to this Seat',
                  onTap: () {
                    Navigator.pop(context);
                    _sitDown(index);
                  },
                )
              else if (!canManage)
                _buildSeatOption(
                  icon: Iconsax.lock,
                  title: context.l10n.room_seatLocked,
                  color: Colors.amber,
                  onTap: null,
                ),
              _buildSeatOption(
                icon: Icons.event_seat,
                title: context.l10n.room_invite,
                onTap: canManage
                    ? () {
                        Navigator.pop(context);
                        _showSeatInviteSearchSheet(seatIndex: index);
                      }
                    : null,
                color: canManage ? Colors.greenAccent : Colors.white24,
              ),
              _buildSeatOption(
                icon: Iconsax.message_add,
                title: 'Invite to Room (search)',
                onTap: () {
                  Navigator.pop(context);
                  _showSeatInviteSearchSheet(seatIndex: index);
                },
              ),
            ] else if (isMe) ...[
              _buildSeatOption(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                title: _isMuted
                    ? context.l10n.room_unmute
                    : context.l10n.room_mute,
                onTap: () {
                  Navigator.pop(context);
                  _toggleMic();
                },
              ),
              _buildSeatOption(
                icon: Iconsax.user,
                title: context.l10n.room_viewProfile,
                onTap: () {
                  Navigator.pop(context);
                  final uid = seat['user_id'].toString();
                  _showUserMiniProfile(
                    uid,
                    username: username,
                    seatIndex: index,
                  );
                },
              ),
              _buildSeatOption(
                icon: Iconsax.logout,
                title: context.l10n.room_leaveMic,
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  _leaveSeat(index);
                },
              ),
            ] else ...[
              _buildSeatOption(
                icon: Iconsax.message,
                title: context.l10n.room_chat,
                onTap: () {
                  Navigator.pop(context);
                  _openPrivateChat(
                    seat['user_id'].toString(),
                    username,
                    avatarUrl: seat['user']?['avatar_url'] as String?,
                  );
                },
              ),
              _buildSeatOption(
                icon: Iconsax.user,
                title: context.l10n.room_viewProfile,
                onTap: () {
                  Navigator.pop(context);
                  final uid = seat['user_id'].toString();
                  _showUserMiniProfile(
                    uid,
                    username: username,
                    seatIndex: index,
                  );
                },
              ),
              if (showMakeAdmin)
                _buildSeatOption(
                  icon: Iconsax.shield_tick,
                  title: context.l10n.room_makeAdmin,
                  color: Colors.amber,
                  onTap: () {
                    Navigator.pop(context);
                    _inviteUserAsAdmin(targetUserId!, username);
                  },
                ),
              if (showRemoveAdmin)
                _buildSeatOption(
                  icon: Iconsax.shield_cross,
                  title: context.l10n.room_removeAdmin,
                  color: Colors.orangeAccent,
                  onTap: () {
                    Navigator.pop(context);
                    _removeUserAsAdmin(targetUserId!, username);
                  },
                ),
              if (canManage &&
                  !peerProtected &&
                  _seats[index]['is_muted'] != true)
                _buildSeatOption(
                  icon: Icons.mic_off,
                  title: context.l10n.room_mute,
                  onTap: () {
                    Navigator.pop(context);
                    _muteUser(index);
                  },
                ),
              if (canManage && !peerProtected)
                _buildSeatOption(
                  icon: Icons.event_seat_outlined,
                  title: context.l10n.room_removeFromSeat,
                  color: Colors.orangeAccent,
                  onTap: () {
                    Navigator.pop(context);
                    _removeUserFromSeat(index);
                  },
                ),
              if (canManage &&
                  !peerProtected &&
                  _canKickUser(seat['user_id'].toString()))
                _buildSeatOption(
                  icon: Icons.block,
                  title: context.l10n.room_addToBlacklist,
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    _kickUserFromRoom(seat['user_id'].toString(), username);
                  },
                ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberQuickActions({
    required BuildContext sheetContext,
    required String userId,
    required String username,
    String? avatarUrl,
    int? seatIndex,
  }) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isSelf = myId != null && userId == myId;

    final canInviteSeat =
        _canManageRoom &&
        !isSelf &&
        !_isUserOnSeat(userId) &&
        _findFirstAvailableSeatIndex() != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canInviteSeat)
          IconButton(
            icon: const Icon(
              Icons.event_seat,
              size: 20,
              color: Colors.greenAccent,
            ),
            tooltip: context.l10n.room_invite,
            onPressed: () {
              Navigator.pop(sheetContext);
              _inviteUserToSeat(
                userId,
                seatIndex: seatIndex,
                username: username,
              );
            },
          ),
        IconButton(
          icon: Icon(
            Iconsax.message,
            size: 20,
            color: isSelf ? Colors.black26 : AppColors.primary,
          ),
          tooltip: context.l10n.room_chat,
          onPressed: isSelf
              ? null
              : () {
                  Navigator.pop(sheetContext);
                  _openPrivateChat(userId, username, avatarUrl: avatarUrl);
                },
        ),
        IconButton(
          icon: Icon(Iconsax.user, size: 20, color: Colors.black54),
          tooltip: context.l10n.room_viewProfile,
          onPressed: () {
            Navigator.pop(sheetContext);
            _showUserMiniProfile(userId, username: username);
          },
        ),
      ],
    );
  }

  Widget _buildSeatOption({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _onSeatInviteAcceptedInRoom() async {
    await _fetchSeats(force: true);
    if (!mounted) return;

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final seatIndex = _mySeatIndex;
    if (myId == null || seatIndex == null) return;

    final seat = _seats[seatIndex];
    final userRaw = seat['user'];
    final userSnapshot = userRaw is Map
        ? Map<String, dynamic>.from(userRaw)
        : () {
            final me = ref.read(userProfileProvider).value;
            return <String, dynamic>{
              'id': myId,
              'username': me?['username'],
              'avatar_url': me?['avatar_url'],
              'vip_level': me?['vip_level'],
            };
          }();

    RoomSeatSyncService.clearVacated(_recentlyVacatedSeatUsers, myId);
    _lastSeatBroadcastAt = DateTime.now();

    await _broadcastSeatAction(
      action: 'sit',
      seatIndex: seatIndex,
      userId: myId,
      user: userSnapshot,
      isMuted: seat['is_muted'] == true,
    );

    await _startSpeaking(seat['is_muted'] != true);
  }

  /// Starts, at seat tap, everything the seat claim does not need to wait for.
  /// Fire-and-forget: if any part fails, taking the seat still works the old way.
  void _prepareSeatVoice(int index) {
    final roomId = widget.room['id']?.toString();
    if (roomId == null || !_useOrbitVoice) return;
    // With an open voice token this is the whole permission step: the mic may
    // publish now, while the seat claim is still on its way.
    OrbitVoiceSessionService.markSitIntent();
    // #region agent log
    final dbgPrepareSw = Stopwatch()..start();
    // #endregion
    unawaited(
      RoomRealtimeSocket.instance
          .seatPrepare({'roomId': roomId, 'seatIndex': index})
          .then((res) {
            // #region agent log
            DebugProbe.log('G', 'room_live_screen:_prepareSeatVoice', 'seat:prepare ack', {
              'ms': dbgPrepareSw.elapsedMilliseconds,
              'ok': res?['ok'],
              'perm': res?['perm'],
              'error': res?['error'],
              'canPublishNow': OrbitVoiceSessionService.canPublishNow,
            });
            // #endregion
          }),
    );
    OrbitVoiceSessionService.warmPublisher();
    unawaited(
      Permission.microphone.isGranted.then((granted) {
        if (granted) OrbitVoiceSessionService.prepareToSpeak();
      }),
    );
  }

  /// The OS microphone prompt belongs at room entry, not in the middle of
  /// taking a seat where it adds its own delay.
  Future<void> _ensureMicPermissionAtEntry() async {
    try {
      if (!await Permission.microphone.isGranted) {
        await Permission.microphone.request();
      }
      // Android 12+ needs BLUETOOTH_CONNECT at runtime before AudioSwitch may
      // see or activate a Bluetooth headset. Without it the earbuds never
      // appear as an output and voice stays on the loudspeaker.
      if (Platform.isAndroid && !await Permission.bluetoothConnect.isGranted) {
        await Permission.bluetoothConnect.request();
      }
    } catch (e) {
      debugPrint('[ROOM] mic permission at entry: $e');
    }
  }

  Future<void> _sitDown(int index) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;
    final sitSw = Stopwatch()..start();
    devLog(
      '[SEAT] sitDown TAP seat=$index mySeat=$_mySeatIndex '
      'zegoReady=$_zegoLoginReady gatewayFlag=$_gatewayJoinReady '
      'joined=${RoomRealtimeSocket.instance.joinedRoomId} '
      'connected=${RoomRealtimeSocket.instance.isConnected}',
    );

    if (_seats[index]['is_locked'] == true && !_canSitOnLockedSeat) {
      devLog('[SEAT] sitDown blocked — seat locked');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This seat is locked. You cannot sit here.'),
          ),
        );
      }
      return;
    }

    // Everything that does not depend on the claim starts now, while the dialog
    // is on screen: the gateway grants publish for this seat, the publisher
    // transport connects, and the mic opens and is published muted. Choosing
    // "Open Mic" is then an unmute instead of grant + capture + publish.
    _prepareSeatVoice(index);

    bool? openMic = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Mic Setting', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Do you want to open your mic on this seat?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Muted'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Mic'),
          ),
        ],
      ),
    );

    if (openMic == null) {
      devLog('[SEAT] sitDown cancelled (dialog dismissed)');
      OrbitVoiceSessionService.clearSitIntent();
      OrbitVoiceSessionService.discardPrecapturedMic();
      return;
    }

    var wantOpenMic = openMic;
    if (!wantOpenMic) OrbitVoiceSessionService.discardPrecapturedMic();
    if (wantOpenMic) {
      // Asked once on room entry; only prompt here if that was declined.
      final alreadyGranted = await Permission.microphone.isGranted;
      final status = alreadyGranted
          ? PermissionStatus.granted
          : await Permission.microphone.request();
      if (!status.isGranted) {
        devLog('[SEAT] sitDown mic permission denied — force muted seat');
        wantOpenMic = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required to open mic.'),
            ),
          );
        }
      }
    }

    // Covers the first-ever grant (permission was only just given) and is a
    // no-op when the tap-time prepare already ran.
    if (wantOpenMic) OrbitVoiceSessionService.prepareToSpeak();
    devLog(
      '[SEAT] sitDown confirmed openMic=$wantOpenMic '
      'ms=${sitSw.elapsedMilliseconds}',
    );
    // #region agent log
    DebugProbe.log('A', 'room_live_screen:_sitDown', 'sit confirmed', {
      'openMic': wantOpenMic,
      'seat': index,
      'tapToConfirmMs': sitSw.elapsedMilliseconds,
      'lkConnected': OrbitVoiceSessionService.isConnected,
      'canPublishNow': OrbitVoiceSessionService.canPublishNow,
    });
    // #endregion

    final supabase = Supabase.instance.client;
    final roomId = widget.room['id'];
    final seatRowId = _seats[index]['id'] as String?;
    final userId = user['id'].toString();
    final userSnapshot = {
      'id': user['id'],
      'username': user['username'],
      'avatar_url': user['avatar_url'],
      'vip_level': user['vip_level'],
    };

    final previousSeatIndex = _mySeatIndex;
    if (mounted) {
      setState(() {
        if (previousSeatIndex != null && previousSeatIndex != index) {
          _seats[previousSeatIndex]['user_id'] = null;
          _seats[previousSeatIndex]['user'] = null;
          _seats[previousSeatIndex]['is_muted'] = false;
        }
        _seats[index] = {
          ...Map<String, dynamic>.from(_seats[index]),
          'user_id': userId,
          'user': userSnapshot,
          'is_muted': !wantOpenMic,
          'is_locked': false,
        };
        _mySeatIndex = index;
        _isMuted = !wantOpenMic;
        _updateAudienceList();
      });
    }
    if (wantOpenMic) {
      _localUnmuteGuardUntil = DateTime.now().add(const Duration(seconds: 8));
    } else {
      _localUnmuteGuardUntil = null;
    }

    RoomSeatSyncService.invalidateSeatRelease(roomId.toString(), userId);
    RoomSeatSyncService.clearVacated(_recentlyVacatedSeatUsers, userId);
    _lastSeatBroadcastAt = DateTime.now();
    devLog(
      '[SEAT] sitDown optimistic applied seat=$index '
      'prevSeat=$previousSeatIndex ms=${sitSw.elapsedMilliseconds}',
    );

    // Optimistic: the prepared track is already published, so unmuting costs one
    // signalling message. It runs alongside the claim; a rejected claim mutes
    // and unpublishes again in the rollback below.
    // If the grant has not landed yet (confirmed faster than the prepare), it is
    // awaited here instead of waiting for the claim ack to start.
    if (wantOpenMic && OrbitVoiceSessionService.isConnected) {
      unawaited(() async {
        if (await OrbitVoiceSessionService.waitForPublishPermission(
          timeout: const Duration(seconds: 3),
        )) {
          await OrbitVoiceSessionService.setMicEnabled(true);
        }
      }());
    }

    var claimSucceeded = false;
    try {
      final claimed = await _claimSeatWithRetry(
        index: index,
        userId: userId,
        userSnapshot: userSnapshot,
        isMuted: !wantOpenMic,
      );
      if (!claimed) {
        final sock = RoomRealtimeSocket.instance;
        if (!sock.isConnected || !sock.isJoinedTo(roomId.toString())) {
          throw StateError('offline');
        }
        throw StateError('Gateway seat claim rejected');
      }
      claimSucceeded = true;
      _seatSessionGeneration++;
      _lastSeatBroadcastAt = DateTime.now();
      devLog(
        '[SEAT] sitDown CLAIM OK seat=$index gen=$_seatSessionGeneration '
        'ms=${sitSw.elapsedMilliseconds}',
      );
      // #region agent log
      DebugProbe.log('A', 'room_live_screen:_sitDown', 'claim ack', {
        'seat': index,
        'tapToAckMs': sitSw.elapsedMilliseconds,
      });
      // #endregion

      if (!AppConstants.useRealtimeGateway) {
        if (previousSeatIndex != null && previousSeatIndex != index) {
          unawaited(
            _broadcastSeatAction(
              action: 'leave',
              seatIndex: previousSeatIndex,
              userId: userId,
            ),
          );
        }
        await supabase
            .from('room_seats')
            .delete()
            .eq('room_id', roomId)
            .eq('user_id', userId);

        if (seatRowId != null) {
          var update = supabase
              .from('room_seats')
              .update({
                'user_id': userId,
                'is_muted': !wantOpenMic,
                'is_locked': false,
              })
              .eq('id', seatRowId);
          if (!_canSitOnLockedSeat) {
            update = update.eq('is_locked', false);
          }
          await update;
        } else {
          await supabase.from('room_seats').insert({
            'room_id': roomId,
            'user_id': userId,
            'seat_index': index,
            'is_muted': !wantOpenMic,
            'is_locked': false,
          });
        }
      }

      devLog('[SEAT] sitDown scheduling startSpeaking');
      unawaited(_startSpeaking(wantOpenMic));
      devLog(
        '[SEAT] sitDown DONE ok seat=$index ms=${sitSw.elapsedMilliseconds}',
      );
    } catch (e, st) {
      devLog('[SEAT] sitDown ERROR claimSucceeded=$claimSucceeded err=$e');
      debugPrint('$st');
      if (claimSucceeded) {
        devLog('[SEAT] sitDown keep seat after post-claim error');
        return;
      }
      OrbitVoiceSessionService.clearSitIntent();
      unawaited(OrbitVoiceSessionService.unpublishMic());
      devLog('[SEAT] sitDown rollback → force fetchSeats');
      await _fetchSeats(force: true);
      if (mounted) {
        final msg = _seatClaimErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _seatClaimErrorMessage(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('unauthorized') ||
        s.contains('no supabase access token') ||
        s.contains('offline')) {
      return 'Connection issue. Please try sitting again.';
    }
    if (s.contains('locked')) {
      return 'This seat is locked. You cannot sit here.';
    }
    if (s.contains('timeout')) {
      return 'Seat claim timed out. Please try again.';
    }
    return 'Could not take this seat. Please try again.';
  }

  Future<void> _leaveSeat(int index) async {
    final seat = _seats[index];
    final supabase = Supabase.instance.client;
    final userId = seat['user_id']?.toString();
    final roomId = widget.room['id'].toString();
    final seatRowId = seat['id'];
    final leavingSelf =
        userId != null &&
        userId == Supabase.instance.client.auth.currentUser?.id;

    if (leavingSelf) {
      await _stopSharedAudioIfUploader(reason: 'leave_seat');
    }

    if (mounted) {
      setState(() {
        _seats[index]['user_id'] = null;
        _seats[index]['user'] = null;
        _seats[index]['is_muted'] = false;
        if (_mySeatIndex == index) _mySeatIndex = null;
        _updateAudienceList();
      });
    }

    if (userId != null) {
      RoomSeatSyncService.markVacated(_recentlyVacatedSeatUsers, userId);
      _lastSeatBroadcastAt = DateTime.now();
      unawaited(
        _broadcastSeatAction(action: 'leave', seatIndex: index, userId: userId),
      );
    }

    if (_useOrbitVoice) {
      _orbitCanPublish = false;
      _isLocalPublishing = false;
      unawaited(() async {
        try {
          await OrbitVoiceSessionService.setMicEnabled(false);
          await OrbitVoiceSessionService.fetchSession(
            roomId: roomId,
            openMic: false,
            onSeat: false,
            leaveSeat: true,
            billingOnly: true,
          );
          if (RoomRealtimeSocket.instance.gatewayRevokesPublishOnLeave) {
            // The gateway takes publish back server-side on seat leave, so the
            // connection stays up. Reconnecting here used to cost 4-10 s of
            // silence and threw away the warmed publisher for the next seat.
            await OrbitVoiceSessionService.unpublishMic();
            _zegoLoginReady = true;
            return;
          }
          final session = await OrbitVoiceSessionService.fetchSession(
            roomId: roomId,
            openMic: false,
            onSeat: false,
          );
          final token = session?['token']?.toString() ?? '';
          final url = session?['livekit_url']?.toString() ?? '';
          if (token.isNotEmpty && url.isNotEmpty) {
            await OrbitVoiceSessionService.connect(
              livekitUrl: url,
              token: token,
              forceReconnect: true,
              skLiveRoomId: roomId,
            );
            _orbitCanPublish = false;
            _zegoLoginReady = true;
          }
        } catch (e) {
          debugPrint('[ORBIT] leave-seat cleanup: $e');
        }
      }());
    } else {
      unawaited(_stopLocalPublishTracked());
    }

    if (AppConstants.useRealtimeGateway) return;

    final releaseGen = userId == null
        ? 0
        : RoomSeatSyncService.scheduleSeatRelease(roomId, userId);

    RoomSeatSyncService.persistAsync(() async {
      if (userId != null &&
          !RoomSeatSyncService.shouldRunSeatRelease(
            roomId,
            userId,
            releaseGen,
          )) {
        return;
      }
      if (seatRowId != null) {
        await supabase.from('room_seats').delete().eq('id', seatRowId);
      } else if (userId != null) {
        await supabase
            .from('room_seats')
            .delete()
            .eq('room_id', roomId)
            .eq('user_id', userId);
      }
    });
  }

  Future<void> _removeUserFromSeat(int index) async {
    if (!_canManageRoom) return;
    if (index < 0 || index >= _seats.length) return;

    final seat = _seats[index];
    final targetUserId = seat['user_id']?.toString();
    if (targetUserId == null) return;

    final actorId = Supabase.instance.client.auth.currentUser?.id;
    if (actorId == null) return;
    if (targetUserId == actorId) {
      await _leaveSeat(index);
      return;
    }

    if (await _isSuperAdminPeerProtected(targetUserId)) {
      _showSuperAdminPeerBlockedSnack();
      return;
    }

    final username = seat['user']?['username'] ?? 'User';
    final seatRowId = seat['id'];
    final roomId = widget.room['id'].toString();

    if (mounted) {
      setState(() {
        _seats[index]['user_id'] = null;
        _seats[index]['user'] = null;
        _seats[index]['is_muted'] = false;
        _updateAudienceList();
      });
    }

    RoomSeatSyncService.markVacated(_recentlyVacatedSeatUsers, targetUserId);
    _lastSeatBroadcastAt = DateTime.now();

    try {
      final ok = await _broadcastSeatAction(
        action: 'leave',
        seatIndex: index,
        userId: targetUserId,
      );
      if (!ok) {
        throw StateError('Gateway force leave rejected');
      }
    } catch (e) {
      debugPrint('Remove from seat broadcast error: $e');
      await _fetchSeats(force: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove user from seat'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (!AppConstants.useRealtimeGateway) {
      RoomSeatSyncService.scheduleSeatRelease(roomId, targetUserId);
      RoomSeatSyncService.persistAsync(() async {
        if (seatRowId != null) {
          await Supabase.instance.client
              .from('room_seats')
              .delete()
              .eq('id', seatRowId)
              .eq('user_id', targetUserId);
        } else {
          await Supabase.instance.client
              .from('room_seats')
              .delete()
              .eq('room_id', widget.room['id'])
              .eq('user_id', targetUserId);
        }
      });
    }

    _addSystemMessage('$username was removed from seat by $_managerLabel');
  }

  Future<void> _muteUser(int index) async {
    final seat = _seats[index];
    if (seat['user_id'] == null) return;
    if (seat['is_muted'] == true) return;

    final userId = seat['user_id']?.toString();
    if (userId != null && await _isSuperAdminPeerProtected(userId)) {
      _showSuperAdminPeerBlockedSnack();
      return;
    }

    if (mounted) {
      setState(() => _seats[index]['is_muted'] = true);
    }

    unawaited(
      _broadcastSeatAction(
        action: 'admin_mute',
        seatIndex: index,
        userId: userId,
        isMuted: true,
      ),
    );

    if (AppConstants.useRealtimeGateway) {
      _addSystemMessage(
        '${seat['user']?['username'] ?? 'User'} was muted by Admin',
      );
      return;
    }

    RoomSeatSyncService.persistAsync(() async {
      await Supabase.instance.client
          .from('room_seats')
          .update({'is_muted': true})
          .eq('id', seat['id']);
      if (mounted) {
        _addSystemMessage(
          '${seat['user']?['username'] ?? 'User'} was muted by Admin',
        );
      }
    });
  }

  Future<void> _toggleSeatLock(int index) async {
    final seat = _seats[index];
    final bool newLockState = !(seat['is_locked'] ?? false);
    final supabase = Supabase.instance.client;
    final roomId = widget.room['id'];

    if (mounted) {
      setState(() {
        _seats[index]['is_locked'] = newLockState;
      });
    }

    unawaited(
      _broadcastSeatAction(
        action: 'lock',
        seatIndex: index,
        isLocked: newLockState,
      ),
    );

    if (AppConstants.useRealtimeGateway) {
      _addSystemMessage(
        'Seat ${index + 1} was ${newLockState ? 'locked' : 'unlocked'} by Admin',
      );
      return;
    }

    try {
      if (seat['id'] != null) {
        await supabase
            .from('room_seats')
            .update({'is_locked': newLockState})
            .eq('id', seat['id']);
      } else if (newLockState) {
        await supabase.from('room_seats').upsert({
          'room_id': roomId,
          'seat_index': index,
          'is_locked': true,
        }, onConflict: 'room_id,seat_index');
      }

      _addSystemMessage(
        'Seat ${index + 1} was ${newLockState ? 'locked' : 'unlocked'} by Admin',
      );
    } catch (e) {
      debugPrint('Lock error: $e');
      if (mounted) {
        setState(() => _seats[index]['is_locked'] = !newLockState);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update seat lock'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _roomAnnouncementText() {
    final data = _roomData;
    final raw = (data != null && data.containsKey('announcement'))
        ? data['announcement']
        : widget.room['announcement'];
    return raw?.toString().trim() ?? '';
  }

  Widget _buildRoomAnnouncementBar() {
    final text = _roomAnnouncementText();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: GestureDetector(
        onTap: _showRoomAnnouncement,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            const Icon(Iconsax.document_text, color: Colors.amber, size: 16),
            const SizedBox(width: 6),
            Expanded(child: _AnnouncementMarquee(text: text)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTabs() {
    return RoomChatTabs(
      activeTab: _activeTab,
      onTabSelected: _setActiveChatTab,
    );
  }

  GlobalKey _anchorKeyFor(String userId) {
    return _memberAnchorKeys.putIfAbsent(userId, GlobalKey.new);
  }

  Offset _offsetFromKey(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    final position = box.localToGlobal(Offset.zero);
    return Offset(
      position.dx + box.size.width / 2,
      position.dy + box.size.height / 2,
    );
  }

  Offset _getOffsetForUser(String userId, {GlobalKey? fallbackKey}) {
    final normalized = _normalizePresenceUserId(userId) ?? userId;
    for (var i = 0; i < _seats.length; i++) {
      final seat = _seats[i];
      final seatUid =
          _normalizePresenceUserId(seat['user_id']) ??
          _normalizePresenceUserId(
            seat['user'] is Map ? seat['user']['id'] : null,
          );
      if (seatUid == normalized && i < _seatKeys.length) {
        final offset = _offsetFromKey(_seatKeys[i]);
        if (offset != Offset.zero) return offset;
      }
    }

    final audienceKey =
        _memberAnchorKeys[normalized] ?? _memberAnchorKeys[userId];
    if (audienceKey != null) {
      final offset = _offsetFromKey(audienceKey);
      if (offset != Offset.zero) return offset;
    }

    if (fallbackKey != null) {
      final offset = _offsetFromKey(fallbackKey);
      if (offset != Offset.zero) return offset;
    }

    final size = MediaQuery.sizeOf(context);
    return Offset(size.width / 2, size.height / 2);
  }

  Offset _getOffsetForSeatIndex(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= _seatKeys.length) {
      return Offset.zero;
    }
    return _offsetFromKey(_seatKeys[seatIndex]);
  }

  void _playMicEmojiOverlay({
    required int seatIndex,
    required String imageUrl,
    String? svgaUrl,
    String? dedupeKey,
  }) {
    if (imageUrl.isEmpty && (svgaUrl == null || svgaUrl.isEmpty)) return;

    _micEmojiOverlayController.play(
      RoomMicEmojiOverlayRequest(
        seatIndex: seatIndex,
        imageUrl: imageUrl,
        svgaUrl: svgaUrl,
        dedupeKey: dedupeKey,
        resolveCenter: _getOffsetForSeatIndex,
      ),
    );
  }

  void _playMicEmojiFromMessage(Map<String, dynamic> msg) {
    final rawMeta = msg['metadata'];
    if (rawMeta == null) return;

    final metadata = rawMeta is Map<String, dynamic>
        ? rawMeta
        : Map<String, dynamic>.from(rawMeta as Map);

    final seatIndex = (metadata['seat_index'] as num?)?.toInt();
    if (seatIndex == null) return;

    final messageId = msg['id']?.toString() ?? '';
    if (messageId.isNotEmpty &&
        _micEmojiOverlayController.hasPlayed(messageId)) {
      return;
    }

    _playMicEmojiOverlay(
      seatIndex: seatIndex,
      imageUrl: metadata['image_url']?.toString() ?? '',
      svgaUrl: metadata['svga_url']?.toString(),
      dedupeKey: messageId.isNotEmpty ? messageId : null,
    );
  }

  void _showMicEmojiSheet() {
    if (_mySeatIndex == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoomMicEmojiSheet(
        roomId: widget.room['id'].toString(),
        seatIndex: _mySeatIndex!,
        onSent: (emoji, messageId) {
          _playMicEmojiOverlay(
            seatIndex: _mySeatIndex!,
            imageUrl: emoji.imageUrl,
            svgaUrl: emoji.svgaUrl,
            dedupeKey: messageId,
          );
          unawaited(
            _broadcastMicEmoji(
              seatIndex: _mySeatIndex!,
              imageUrl: emoji.imageUrl,
              svgaUrl: emoji.svgaUrl,
              emojiId: emoji.id,
              eventId: messageId,
            ),
          );
        },
      ),
    );
  }

  void _stopGiftAnimations() {
    _giftFlightController.clearAll();
    _micEmojiOverlayController.clearAll();
    _cancelPendingLuckyGiftComments();
    _seenFullScreenGiftBatchIds.clear();
    _fullScreenGiftQueue.clear();
    if (_fullScreenGiftOverlayEntry?.mounted == true) {
      _fullScreenGiftOverlayEntry!.remove();
    }
    _fullScreenGiftOverlayEntry = null;
    _fullScreenGiftShowing = false;
    _activeLuckyFanbis.clear();
    _activeLuckyMultipliers.clear();
    _repeatGiftQueue.clear();
    _repeatGiftDraining = false;
  }

  bool _truthyBool(dynamic value) {
    if (value == true || value == 1) return true;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  ({
    bool isFullScreen,
    String svgaUrl,
    String giftIcon,
    int quantity,
    List<String> targetIds,
  })
  _giftAnimationFieldsFromPayload(
    Map<String, dynamic> payload,
    List<Map<String, dynamic>> giftMessages,
  ) {
    var isFullScreen =
        _truthyBool(payload['is_full_screen']) ||
        _truthyBool(payload['isFullScreen']);
    var svgaUrl =
        payload['svga_url']?.toString() ?? payload['svgaUrl']?.toString() ?? '';
    var giftIcon =
        payload['gift_icon']?.toString() ??
        payload['giftIcon']?.toString() ??
        '';
    var quantity = (payload['quantity'] as num?)?.toInt() ?? 1;
    final targetIds = <String>[];

    final targetIdsRaw = payload['target_ids'] ?? payload['targetIds'];
    if (targetIdsRaw is List) {
      for (final id in targetIdsRaw) {
        final resolved = id?.toString() ?? '';
        if (resolved.isNotEmpty) targetIds.add(resolved);
      }
    }

    for (final msg in giftMessages) {
      final meta = msg['metadata'];
      if (meta is! Map) continue;
      final metadata = Map<String, dynamic>.from(meta);
      if (!isFullScreen) {
        isFullScreen = _truthyBool(metadata['is_full_screen']);
      }
      if (svgaUrl.isEmpty) {
        svgaUrl = metadata['svga_url']?.toString() ?? '';
      }
      if (giftIcon.isEmpty) {
        giftIcon = metadata['gift_icon']?.toString() ?? '';
      }
      quantity = (metadata['quantity'] as num?)?.toInt() ?? quantity;
      final targetId = metadata['target_id']?.toString() ?? '';
      if (targetId.isNotEmpty && !targetIds.contains(targetId)) {
        targetIds.add(targetId);
      }
    }

    return (
      isFullScreen: isFullScreen,
      svgaUrl: svgaUrl,
      giftIcon: giftIcon,
      quantity: quantity,
      targetIds: targetIds,
    );
  }

  void _maybeShowFullScreenGiftAnimation({
    required String batchId,
    required String svgaUrl,
    required bool isFullScreen,
    String fallbackIconUrl = '',
  }) {
    if (!isFullScreen || svgaUrl.isEmpty || !mounted) return;

    final dedupeKey = batchId.isNotEmpty ? 'fs_$batchId' : svgaUrl;
    if (_seenFullScreenGiftBatchIds.contains(dedupeKey)) return;
    _seenFullScreenGiftBatchIds.add(dedupeKey);
    while (_seenFullScreenGiftBatchIds.length > _maxSeenBroadcastIds) {
      _seenFullScreenGiftBatchIds.remove(_seenFullScreenGiftBatchIds.first);
    }
    _showFullScreenGift(svgaUrl, fallbackIconUrl: fallbackIconUrl);
  }

  List<Map<String, dynamic>> _getGiftTargetMembers() {
    final uniqueMembers = <String, Map<String, dynamic>>{};
    for (final seat in _seats) {
      if (seat['user'] != null) {
        final user = Map<String, dynamic>.from(seat['user']);
        uniqueMembers[user['id'].toString()] = user;
      }
    }
    return uniqueMembers.values.toList();
  }

  void _showGiftSheet() {
    _pruneGiftTargetIfNeeded();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoomGiftSheet(
        room: _roomData ?? widget.room,
        seats: _seats,
        audience: _audience,
        initialSelectedUserIds: Set<String>.from(_giftTargetUserIds),
        initialIsAllSelected: _giftTargetAllSelected,
        onTargetSelectionChanged: (userIds, isAll) {
          _giftTargetUserIds
            ..clear()
            ..addAll(userIds);
          _giftTargetAllSelected = isAll;
        },
        onGiftSent: _onGiftSentOptimistic,
        onGiftBroadcast: _onGiftBroadcastFromSender,
        onRepeatGiftReady: (session) {
          if (!mounted) return;
          final current = _repeatGiftSession;
          if (current == null || !_isSameRepeatGift(current, session)) {
            _repeatComboCount = 1;
          }
          _armRepeatGiftSession(session);
        },
      ),
    );
  }

  void _pruneGiftTargetIfNeeded() {
    final seatedIds = _seats
        .map((seat) => seat['user']?['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    _giftTargetUserIds.removeWhere((id) => !seatedIds.contains(id));
    if (_giftTargetAllSelected &&
        seatedIds.isNotEmpty &&
        seatedIds.every(_giftTargetUserIds.contains)) {
      return;
    }
    _giftTargetAllSelected =
        seatedIds.isNotEmpty && seatedIds.every(_giftTargetUserIds.contains);
  }

  void _armRepeatGiftSession(RepeatGiftSession session) {
    _repeatGiftHideTimer?.cancel();
    // Fresh session: re-baseline local coins from the profile on the next tap.
    final wasHidden = _repeatGiftSession == null;
    if (wasHidden) {
      _giftCoinsLocal = -1;
      if (_repeatComboCount <= 0) _repeatComboCount = 1;
    }
    _repeatGiftSession = session;
    // Only showing/hiding the button needs the room rebuilt; a tap on a
    // visible button just restarts its ring through the notifier.
    if (wasHidden) setState(() {});
    _repeatComboTick.value++;
    _repeatGiftHideTimer = Timer(_repeatGiftVisibleFor, () {
      if (!mounted) return;
      _repeatComboCount = 0;
      setState(() => _repeatGiftSession = null);
      _armBonusPattiHide();
    });
  }

  void _clearRepeatGiftSession() {
    _repeatGiftHideTimer?.cancel();
    _repeatGiftHideTimer = null;
    _giftCoinsLocal = -1;
    _repeatComboCount = 0;
    if (_repeatGiftSession != null && mounted) {
      setState(() => _repeatGiftSession = null);
    } else {
      _repeatGiftSession = null;
    }
    _armBonusPattiHide();
  }

  int _giftCoinsAvailable(Map<String, dynamic> myUser) {
    syncWalletCoinsOverrideFromProfile(ref, myUser);
    final override = ref.read(walletCoinsOverrideProvider);
    final profile = override ?? (myUser['coins'] as num?)?.toInt() ?? 0;
    if (_giftCoinsLocal < 0) {
      _giftCoinsLocal = profile;
    } else if (profile < _giftCoinsLocal) {
      // Stream / override caught up with a spend (or a lower server truth).
      _giftCoinsLocal = profile;
    } else if (!_repeatGiftDraining &&
        _repeatGiftQueue.isEmpty &&
        profile > _giftCoinsLocal) {
      // Idle + higher profile = top-up / refresh.
      _giftCoinsLocal = profile;
    }
    return _giftCoinsLocal;
  }

  void _showInsufficientGiftToastOnce() {
    final now = DateTime.now();
    final last = _lastInsufficientGiftToastAt;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return;
    }
    _lastInsufficientGiftToastAt = now;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.room_insufficientCoins),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static bool _isInsufficientGiftError(String? message) {
    if (message == null || message.isEmpty) return false;
    final l = message.toLowerCase();
    return l.contains('insufficient') ||
        l.contains('not enough') ||
        l.contains('balance') ||
        l.contains('no coin');
  }

  bool _isSameRepeatGift(RepeatGiftSession a, RepeatGiftSession b) {
    if (a.giftId != b.giftId || a.quantity != b.quantity) return false;
    if (a.targetIds.length != b.targetIds.length) return false;
    for (var i = 0; i < a.targetIds.length; i++) {
      if (a.targetIds[i] != b.targetIds[i]) return false;
    }
    return true;
  }

  int _repeatGiftUnitCost(RepeatGiftSession session) {
    final targets = session.targetIds.length;
    if (targets <= 0) return 0;
    return session.priceCoins * session.quantity * targets;
  }

  void _playRepeatGiftFxNow({
    required RepeatGiftSession session,
    required Map<String, dynamic> myUser,
    required String animationBatchId,
  }) {
    final targets = session.targetIds;
    _onGiftSentOptimistic(
      animationBatchId: animationBatchId,
      senderId: myUser['id'].toString(),
      targetIds: targets,
      giftIcon: session.giftIcon,
      quantity: session.quantity,
      isFullScreen: session.isFullScreen,
      svgaUrl: session.svgaUrl,
      playFullScreenSvga: session.isFullScreen,
      priceCoins: session.priceCoins,
      giftName: session.giftName,
    );
    // No pre-settle room broadcast here: the gateway's gift:send emits the
    // settled room_gift to everyone. A per-tap gift:notify doubled the room
    // fan-out and showed peers gifts that could still fail on balance.
  }

  void _enqueueRepeatGift() {
    final session = _repeatGiftSession;
    if (session == null) return;

    final now = DateTime.now();
    final last = _lastRepeatGiftAt;
    if (last != null && now.difference(last) < _repeatGiftMinInterval) {
      return;
    }
    _lastRepeatGiftAt = now;

    final myUser = ref.read(userProfileProvider).value;
    if (myUser == null) return;

    final targets = session.targetIds;
    if (targets.isEmpty) return;

    final unitCost = _repeatGiftUnitCost(session);
    final coins = _giftCoinsAvailable(myUser);
    if (coins < unitCost) {
      _showInsufficientGiftToastOnce();
      // Stop the floating repeat button so holding/tapping cannot spam toasts.
      _clearRepeatGiftSession();
      return;
    }

    final tail = _repeatGiftQueue.isEmpty ? null : _repeatGiftQueue.last;
    final mergeIntoTail =
        tail != null &&
        _isSameRepeatGift(tail.session, session) &&
        tail.quantity + session.quantity <= _maxRepeatGiftQuantity;
    if (!mergeIntoTail && _repeatGiftQueue.length >= _maxRepeatGiftQueued) {
      debugPrint(
        '[GIFT_DRAIN] tap dropped — queue full (${_repeatGiftQueue.length})',
      );
      return;
    }

    final animationBatchId = const Uuid().v4();
    // Optimistic deduct so the next tap sees the spend before the profile stream.
    _giftCoinsLocal = coins - unitCost;
    ref.read(walletCoinsOverrideProvider.notifier).state = _giftCoinsLocal;
    if (mergeIntoTail) {
      tail.taps += 1;
      tail.unitCost += unitCost;
    } else {
      _repeatGiftQueue.add(
        _PendingRepeatGift(
          animationBatchId: animationBatchId,
          unitCost: unitCost,
          session: session,
        ),
      );
    }
    _repeatComboCount += 1;
    _armRepeatGiftSession(session);
    _playRepeatGiftFxNow(
      session: session,
      myUser: myUser,
      animationBatchId: animationBatchId,
    );
    unawaited(_drainRepeatGiftQueue());
  }

  Future<void> _drainRepeatGiftQueue() async {
    if (_repeatGiftDraining) return;
    _repeatGiftDraining = true;
    _isRepeatSending = true;

    final drainSw = Stopwatch()..start();
    final startDepth = _repeatGiftQueue.length;
    final peekTargets = _repeatGiftQueue.isEmpty
        ? 0
        : _repeatGiftQueue.first.session.targetIds.length;
    debugPrint(
      '[GIFT_DRAIN] start depth=$startDepth targetsPerTap=$peekTargets '
      'maxInFlight=$_maxRepeatGiftInFlight',
    );

    final inFlight = <Future<void>>[];

    Future<void> launch(_PendingRepeatGift pending) {
      late Future<void> f;
      f = () async {
        try {
          final result = await _sendOneRepeatGiftDetailed(
            pending.session,
            animationBatchId: pending.animationBatchId,
            quantity: pending.quantity,
            expectedSpend: pending.unitCost,
          );
          if (!result.ok) {
            // Refund optimistic spend; the coins never left the wallet.
            _giftCoinsLocal =
                (_giftCoinsLocal < 0 ? 0 : _giftCoinsLocal) + pending.unitCost;
            ref.read(walletCoinsOverrideProvider.notifier).state =
                _giftCoinsLocal;
            debugPrint(
              'Repeat gift RPC failed for ${pending.animationBatchId}',
            );
            if (result.insufficient) {
              _showInsufficientGiftToastOnce();
              _clearRepeatGiftQueueAndSession();
            }
          }
        } finally {
          inFlight.remove(f);
        }
      }();
      inFlight.add(f);
      return f;
    }

    while (_repeatGiftQueue.isNotEmpty || inFlight.isNotEmpty) {
      while (_repeatGiftQueue.isNotEmpty &&
          inFlight.length < _maxRepeatGiftInFlight) {
        final pending = _repeatGiftQueue.removeFirst();
        launch(pending);
      }
      if (inFlight.isNotEmpty) {
        await Future.any(inFlight);
      }
    }

    debugPrint(
      '[GIFT_DRAIN] done startDepth=$startDepth '
      'elapsed=${drainSw.elapsedMilliseconds}ms',
    );

    _repeatGiftDraining = false;
    _isRepeatSending = false;
  }

  void _clearRepeatGiftQueueAndSession() {
    // Drop queued taps that have not launched yet (optimistic spend refunded).
    while (_repeatGiftQueue.isNotEmpty) {
      final pending = _repeatGiftQueue.removeFirst();
      _giftCoinsLocal =
          (_giftCoinsLocal < 0 ? 0 : _giftCoinsLocal) + pending.unitCost;
    }
    if (_giftCoinsLocal >= 0) {
      ref.read(walletCoinsOverrideProvider.notifier).state = _giftCoinsLocal;
    }
    _clearRepeatGiftSession();
  }

  Future<({bool ok, bool insufficient})> _sendOneRepeatGiftDetailed(
    RepeatGiftSession session, {
    required String animationBatchId,
    required int quantity,
    required int expectedSpend,
  }) async {
    final myUser = ref.read(userProfileProvider).value;
    if (myUser == null) return (ok: false, insufficient: false);

    final targets = session.targetIds;
    if (targets.isEmpty) return (ok: false, insufficient: false);

    final members = _getGiftTargetMembers();

    try {
      final outcomes = session.usesGatewaySettle
          ? await sendRoomGiftsViaGateway(
              supabase: Supabase.instance.client,
              roomId: (_roomData ?? widget.room)['id'].toString(),
              myUser: myUser,
              targetIds: targets,
              gift: session.toGiftMap(),
              quantity: quantity,
              animationBatchId: animationBatchId,
              allMembers: members,
            )
          : await Future.wait(
              targets.map(
                (targetId) => sendRoomGift(
                  supabase: Supabase.instance.client,
                  roomId: (_roomData ?? widget.room)['id'].toString(),
                  myUser: myUser,
                  targetId: targetId,
                  gift: session.toGiftMap(),
                  quantity: quantity,
                  animationBatchId: animationBatchId,
                  allMembers: members,
                ),
              ),
            );

      final successfulTargets = <String>[];
      var anyLuckyWin = false;
      var totalSpent = 0;
      var insufficient = false;
      for (var i = 0; i < targets.length; i++) {
        if (i >= outcomes.length) continue;
        final o = outcomes[i];
        if (_isInsufficientGiftError(o.errorMessage)) {
          insufficient = true;
        }
        if (!o.success) continue;
        successfulTargets.add(targets[i]);
        totalSpent += session.priceCoins * quantity;
        if (o.luckyWin) anyLuckyWin = true;
      }

      if (successfulTargets.isEmpty) {
        return (ok: false, insufficient: insufficient);
      }

      // Partial success (some targets paid): refund the unpaid share of the
      // optimistic full-unit deduct so the local balance stays honest.
      final unpaid = expectedSpend - totalSpent;
      if (unpaid > 0) {
        _giftCoinsLocal = (_giftCoinsLocal < 0 ? 0 : _giftCoinsLocal) + unpaid;
        ref.read(walletCoinsOverrideProvider.notifier).state = _giftCoinsLocal;
      }
      if (insufficient) {
        // Do not keep hammering once the server says the wallet is empty.
        _showInsufficientGiftToastOnce();
        _clearRepeatGiftQueueAndSession();
      }

      if (anyLuckyWin) {
        ref.invalidate(systemNotificationsProvider);
      }

      await _broadcastRepeatGiftOutcomes(
        myUser: myUser,
        outcomes: outcomes,
        targets: targets,
        animationBatchId: animationBatchId,
        giftIcon: session.giftIcon,
        quantity: quantity,
        isFullScreen: session.isFullScreen,
        svgaUrl: session.svgaUrl,
      );

      if (totalSpent > 0) {
        unawaited(
          TaskTrackerService.trackAction('spend_coins', amount: totalSpent),
        );
        unawaited(TaskTrackerService.trackAction('newbie_send_gift'));
      }
      // Keep optimistic wallet; users realtime stream settles truth without
      // flashing loading via invalidate(userProfileProvider).
      return (ok: true, insufficient: insufficient);
    } catch (e) {
      debugPrint('Repeat gift error: $e');
      final msg = e.toString();
      return (ok: false, insufficient: _isInsufficientGiftError(msg));
    }
  }

  Offset _giftSpawnOffset() {
    final size = MediaQuery.sizeOf(context);
    final top = _entranceSlideTop(context);
    return Offset(size.width / 2, top + _entranceBannerHeight * 0.45);
  }

  void _enqueueGiftAnimation({
    String? dedupeKey,
    required String senderId,
    required List<String> targetIds,
    required String giftIcon,
    required int quantity,
    bool isFullScreen = false,
    String svgaUrl = '',
    bool playFullScreenSvga = true,
  }) {
    if (targetIds.isEmpty) return;
    if (giftIcon.isEmpty && !(isFullScreen && svgaUrl.isNotEmpty)) return;

    // The sender's optimistic copy and the settled echo of the same gift
    // share a batch id; count it once.
    final alreadyCounted =
        dedupeKey != null &&
        dedupeKey.isNotEmpty &&
        _giftFlightController.hasPlayed(dedupeKey);
    if (!alreadyCounted) {
      _noteGiftCombo(senderId, quantity);
      _bumpBonusPattiCombo(senderId: senderId, qty: quantity);
    }

    // A game sheet covers the room: no new gift flights behind it (S6).
    if (ref.read(gameOverlayOpenProvider) > 0) return;

    // Full screen goes through the batch guard, never straight from the flight
    // manager: the sender's own send and the echo of it are one gift, and the
    // unguarded path played the SVGA for them a second time.
    if (playFullScreenSvga && isFullScreen && svgaUrl.isNotEmpty) {
      _maybeShowFullScreenGiftAnimation(
        batchId: dedupeKey ?? '',
        svgaUrl: svgaUrl,
        isFullScreen: true,
        fallbackIconUrl: giftIcon,
      );
      if (giftIcon.isEmpty && dedupeKey != null && dedupeKey.isNotEmpty) {
        _giftFlightController.markPlayed(dedupeKey);
      }
    }

    _giftFlightController.enqueue(
      GiftFlightRequest(
        dedupeKey: dedupeKey,
        senderId: '__gift_spawn__',
        targetIds: targetIds,
        imageUrl: giftIcon,
        quantity: quantity,
        isFullScreen: false,
        svgaUrl: svgaUrl,
        holdAtCenter: !(isFullScreen && svgaUrl.isNotEmpty),
        comboKey: senderId,
        resolveOffset: (userId) {
          if (userId == '__gift_spawn__') {
            return _giftSpawnOffset();
          }
          return _getOffsetForUser(userId, fallbackKey: _audienceKey);
        },
      ),
    );
  }

  void _onGiftSentOptimistic({
    required String animationBatchId,
    required String senderId,
    required List<String> targetIds,
    required String giftIcon,
    required int quantity,
    required bool isFullScreen,
    required String svgaUrl,
    bool playFullScreenSvga = true,
    int priceCoins = 0,
    String? giftName,
  }) {
    final isBigGiftPatti = BigGiftPattiUtil.meetsThreshold(
      priceCoins: priceCoins,
      quantity: quantity,
    );
    _enqueueGiftAnimation(
      dedupeKey: animationBatchId,
      senderId: senderId,
      targetIds: targetIds,
      giftIcon: giftIcon,
      quantity: quantity,
      isFullScreen: isFullScreen,
      svgaUrl: svgaUrl,
      playFullScreenSvga: playFullScreenSvga,
    );

    if (isBigGiftPatti) {
      final profile = ref.read(userProfileProvider).value;
      _enqueueBigGiftPatti(
        dedupeKey: 'big_$animationBatchId',
        username: profile?['username']?.toString() ?? 'User',
        avatarUrl: profile?['avatar_url']?.toString(),
        giftName: giftName,
        giftCoins: BigGiftPattiUtil.totalCoins(
          priceCoins: priceCoins,
          quantity: quantity,
        ),
        senderId: senderId,
      );
    }
  }

  void _enqueueBigGiftPatti({
    required String dedupeKey,
    required String username,
    required int giftCoins,
    String? avatarUrl,
    String? giftName,
    String? senderId,
  }) {
    if (giftCoins < BigGiftPattiUtil.thresholdCoins) return;

    final resolvedAvatar = _resolveBigGiftAvatarUrl(
      avatarUrl: avatarUrl,
      senderId: senderId,
    );

    ref
        .read(bigGiftPattiBroadcastControllerProvider.notifier)
        .enqueue(
          BigGiftPattiAnnouncement(
            id: dedupeKey,
            userId: senderId,
            username: username,
            avatarUrl: resolvedAvatar,
            giftName: giftName,
            giftCoins: giftCoins,
            roomId: widget.room['id']?.toString(),
          ),
          dedupeKey: dedupeKey,
        );
  }

  String? _resolveBigGiftAvatarUrl({String? avatarUrl, String? senderId}) {
    final direct = avatarUrl?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final uid = senderId?.trim();
    if (uid == null || uid.isEmpty) {
      final me = ref.read(userProfileProvider).value;
      final mine = me?['avatar_url']?.toString().trim();
      return (mine != null && mine.isNotEmpty) ? mine : null;
    }

    for (final u in _onlineUsers) {
      if (u['id']?.toString() == uid) {
        final a = u['avatar_url']?.toString().trim();
        if (a != null && a.isNotEmpty) return a;
      }
    }
    for (final seat in _seats) {
      final user = seat['user'];
      if (user is Map && user['id']?.toString() == uid) {
        final a = user['avatar_url']?.toString().trim();
        if (a != null && a.isNotEmpty) return a;
      }
    }

    final me = ref.read(userProfileProvider).value;
    if (me?['id']?.toString() == uid) {
      final mine = me?['avatar_url']?.toString().trim();
      if (mine != null && mine.isNotEmpty) return mine;
    }
    return null;
  }

  void _maybeEnqueueBigGiftPattiFromGiftMessage(Map<String, dynamic> msg) {
    final metadata = msg['metadata'];
    if (metadata is! Map) return;
    final priceCoins = (metadata['price_coins'] as num?)?.toInt() ?? 0;
    final quantity = (metadata['quantity'] as num?)?.toInt() ?? 1;
    if (!BigGiftPattiUtil.meetsThreshold(
      priceCoins: priceCoins,
      quantity: quantity,
    )) {
      return;
    }

    final batchId = metadata['animation_batch_id']?.toString() ?? '';
    final messageId = msg['id']?.toString() ?? '';
    final dedupeKey = batchId.isNotEmpty
        ? 'big_$batchId'
        : (messageId.isNotEmpty
              ? 'big_$messageId'
              : 'big_${msg['user_id']}_${priceCoins}_$quantity');

    final userRaw = msg['user'];
    final user = userRaw is Map
        ? Map<String, dynamic>.from(userRaw)
        : <String, dynamic>{};

    _enqueueBigGiftPatti(
      dedupeKey: dedupeKey,
      username:
          metadata['sender_username']?.toString() ??
          user['username']?.toString() ??
          'User',
      avatarUrl:
          metadata['sender_avatar']?.toString() ??
          user['avatar_url']?.toString(),
      giftName: metadata['gift_name']?.toString(),
      giftCoins: BigGiftPattiUtil.totalCoins(
        priceCoins: priceCoins,
        quantity: quantity,
      ),
      senderId: msg['user_id']?.toString() ?? metadata['sender_id']?.toString(),
    );
  }

  void _onGiftBroadcastFromSender(Map<String, dynamic> payload) {
    final eventId = payload['event_id']?.toString();
    if (eventId != null) {
      _seenBroadcastEventIds.add(eventId);
    }
    final totals = payload['seat_gift_totals'];
    if (totals is Map) {
      _applySeatGiftTotalsSnapshot(totals);
    } else if (payload['settled_on_gateway'] != true) {
      _applySeatGiftDelta(payload['seat_gift_delta']);
    } else {
      _applySeatGiftDelta(payload['seat_gift_delta']);
    }

    final giftMessages = _giftMessagesFromPayload(payload);
    if (mounted) _appendGiftChatMessages(giftMessages);

    for (final msg in giftMessages) {
      _maybeBroadcastLuckyWinFromGiftMessage(msg);
      _maybeEnqueueBigGiftPattiFromGiftMessage(msg);
    }

    unawaited(_broadcastRoomGift(payload));
  }

  /// Single entry point for the chat line of a gift batch.
  ///
  /// Registers each row's own `event_id` so the `room_messages` insert the
  /// gateway writes for the same gift is dropped by
  /// [_onRoomMessagePostgresReconcile] — only the batch id used to be
  /// registered, which is why the room listed every gift twice.
  void _appendGiftChatMessages(List<Map<String, dynamic>> messages) {
    var added = false;
    for (final msg in messages) {
      _markGiftMessageSeen(msg);
      if (_holdLuckyGiftComment(msg)) continue;
      if (_tryAppendChatMessage(msg, scroll: false)) added = true;
    }
    if (added) _scrollToBottom();
  }

  void _markGiftMessageSeen(Map<String, dynamic> message) {
    final meta = message['metadata'];
    if (meta is! Map) return;
    final eventId = meta['event_id']?.toString();
    if (eventId == null || eventId.isEmpty) return;
    RoomLiveBroadcast.shouldIgnore(
      _seenBroadcastEventIds,
      eventId,
      maxSize: _maxSeenBroadcastIds,
    );
  }

  /// True while a lucky gift's roll is still running on the gateway.
  ///
  /// The gateway fans the gift out first and rolls afterwards, so the message
  /// it broadcasts carries the lucky flags with no result yet. Posting it then
  /// put a comment in chat mid-spin, followed by a second one for the win.
  bool _isLuckyRollPending(Map<String, dynamic> message) {
    if (message['type']?.toString() != 'gift') return false;
    final meta = message['metadata'];
    if (meta is! Map) return false;
    final isLucky =
        meta['is_lucky_gift'] == true || meta['is_lucky_pro_gift'] == true;
    if (!isLucky) return false;
    if (meta['lucky_bonus_won'] == true || meta['lucky_pro_bonus_won'] == true) {
      return false;
    }
    if (meta['lucky_engine']?.toString() != 'gateway') return false;
    return (meta['gift_log_id']?.toString() ?? '').isNotEmpty;
  }

  bool _holdLuckyGiftComment(Map<String, dynamic> message) {
    if (!_isLuckyRollPending(message)) return false;
    final meta = message['metadata'] as Map;
    final giftLogId = meta['gift_log_id'].toString();
    if (_pendingLuckyGiftComments.containsKey(giftLogId)) return true;
    // Claim the row's ids while it waits, so the postgres copy of the same gift
    // cannot post the un-settled line behind our back.
    if (!_claimChatMessageKeys(message)) return true;
    _pendingLuckyGiftComments[giftLogId] = _PendingLuckyGiftComment(
      message: message,
      timer: Timer(_luckyGiftSettleWindow, () {
        // Window elapsed with no win event: the roll lost, post the plain line.
        _releaseLuckyGiftComment(giftLogId);
      }),
    );
    return true;
  }

  void _releaseLuckyGiftComment(
    String giftLogId, {
    Map<String, dynamic>? win,
  }) {
    final pending = _pendingLuckyGiftComments.remove(giftLogId);
    if (pending == null) return;
    pending.timer.cancel();
    if (!mounted) return;
    if (win != null) _mergeLuckyWinIntoGiftMessage(pending.message, win);
    _tryAppendChatMessage(pending.message, keysClaimed: true);
  }

  /// Lands a settled win on its held gift comment, so the room reads one line
  /// carrying both the gift and the multiplier it hit.
  void _settleLuckyGiftComment(Map<String, dynamic> luckyMessage) {
    final meta = luckyMessage['metadata'];
    if (meta is! Map) return;
    final giftLogId = meta['gift_log_id']?.toString() ?? '';
    if (giftLogId.isEmpty) return;
    if (!_pendingLuckyGiftComments.containsKey(giftLogId)) return;
    _releaseLuckyGiftComment(
      giftLogId,
      win: Map<String, dynamic>.from(meta),
    );
  }

  void _mergeLuckyWinIntoGiftMessage(
    Map<String, dynamic> message,
    Map<String, dynamic> win,
  ) {
    final meta = message['metadata'];
    if (meta is! Map) return;
    final isPro =
        win['lucky_pro_bonus_won'] == true || win['is_lucky_pro_gift'] == true;
    final coins = isPro
        ? ((win['lucky_pro_bonus_coins'] as num?)?.toInt() ?? 0)
        : ((win['lucky_bonus_coins'] as num?)?.toInt() ?? 0);
    if (coins <= 0) return;

    final multiplier = _resolveLuckyMultiplier(
      meta,
      coins,
      // The gift row carries a placeholder x1 until the roll lands, so the win
      // event's own value is what counts here.
      reported: (win['bonus_multiplier'] as num?)?.toInt() ?? 0,
    );

    meta['lucky_bonus_won'] = !isPro;
    meta['lucky_pro_bonus_won'] = isPro;
    meta[isPro ? 'lucky_pro_bonus_coins' : 'lucky_bonus_coins'] = coins;
    meta['bonus_multiplier'] = multiplier;
    meta['multiplier_tier'] = RoomWinCardUtil.resolveMultiplierTier(multiplier);
  }

  /// The roll's multiplier, falling back to reward ÷ gift value for gateways
  /// and old rows that only carry the coins.
  int _resolveLuckyMultiplier(Map meta, int rewardCoins, {int? reported}) {
    final declared =
        reported ?? (meta['bonus_multiplier'] as num?)?.toInt() ?? 0;
    if (declared > 0) return declared;
    final giftValue =
        ((meta['price_coins'] as num?)?.toInt() ?? 0) *
        ((meta['quantity'] as num?)?.toInt() ?? 1);
    return RoomWinCardUtil.computeBonusMultiplier(
      rewardCoins: rewardCoins,
      giftValue: giftValue,
    );
  }

  List<Map<String, dynamic>> _giftMessagesFromPayload(
    Map<String, dynamic> payload,
  ) {
    final rawList = payload['messages'];
    if (rawList is List && rawList.isNotEmpty) {
      return rawList
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    final single = payload['message'];
    if (single is Map) {
      return [Map<String, dynamic>.from(single)];
    }
    return const [];
  }

  void _maybeBroadcastLuckyWinFromGiftMessage(Map<String, dynamic> message) {
    final luckyMsg = _buildLuckyWinMessageFromGift(message);
    if (luckyMsg == null) return;

    if (mounted) {
      _tryAppendChatMessage(luckyMsg);
    }

    _maybeEnqueueLuckyWinFloats(luckyMsg);
    _enqueueGlobalWinBanner(luckyMsg);
    unawaited(_broadcastLuckyWin(luckyMsg));
  }

  void _maybeShowLuckyWinFromGiftMessage(Map<String, dynamic> message) {
    final luckyMsg = _buildLuckyWinMessageFromGift(message);
    if (luckyMsg == null || !mounted) return;

    _tryAppendChatMessage(luckyMsg);
    _maybeEnqueueLuckyWinFloats(luckyMsg);
    _enqueueGlobalWinBanner(luckyMsg);
  }

  void _enqueueGlobalWinBanner(Map<String, dynamic> message) {
    if (!AppConstants.enableGlobalWinSvgaBroadcast) return;
    final announcement = RoomWinSyncService.announcementFromRoomMessage(
      message,
    );
    if (announcement == null) return;
    ref
        .read(globalWinBroadcastControllerProvider.notifier)
        .enqueueWin(announcement, dedupeKey: announcement.id);
  }

  void _spawnLuckyFloats({
    required String baseId,
    Map<String, dynamic>? fanbi,
    Map<String, dynamic>? multiplier,
  }) {
    if (fanbi == null && multiplier == null) return;
    if (!mounted) return;

    if (_seenLuckyFloatKeys.contains(baseId)) return;
    _seenLuckyFloatKeys.add(baseId);
    while (_seenLuckyFloatKeys.length > 200) {
      _seenLuckyFloatKeys.remove(_seenLuckyFloatKeys.first);
    }

    final stackY = -(_luckyFloatStackSeq++ % 6) * 28.0;

    setState(() {
      if (fanbi != null) {
        fanbi['stackY'] = stackY;
        _activeLuckyFanbis.add(fanbi);
      }
      if (multiplier != null) {
        multiplier['stackY'] = stackY;
        _activeLuckyMultipliers.add(multiplier);
      }
    });
  }

  void _removeLuckyFanbi(String id) {
    if (!mounted || id.isEmpty) return;
    setState(() {
      _activeLuckyFanbis.removeWhere((e) => e['id']?.toString() == id);
    });
  }

  void _removeLuckyMultiplier(String id) {
    if (!mounted || id.isEmpty) return;
    setState(() {
      _activeLuckyMultipliers.removeWhere((e) => e['id']?.toString() == id);
    });
  }

  void _onBonusPattiDismissed() {
    if (!mounted) return;
    setState(() {
      _bonusPatti = null;
      _bonusPattiVisible = false;
    });
  }

  String _bonusPattiSubtitle(Map<String, dynamic> meta) {
    final session = _repeatGiftSession;
    final me = ref.read(userProfileProvider).value?['id']?.toString();
    final senderId =
        meta['sender_id']?.toString() ?? meta['user_id']?.toString() ?? '';
    if (session != null &&
        me != null &&
        (senderId.isEmpty || senderId == me) &&
        session.targetIds.isNotEmpty) {
      final n = session.targetIds.length;
      return '$n people';
    }

    final ids = meta['target_ids'];
    var count = 0;
    if (ids is List) {
      count = ids.where((e) => e != null && e.toString().isNotEmpty).length;
    }
    if (count <= 0) {
      final one = meta['target_id']?.toString();
      count = (one != null && one.isNotEmpty) ? 1 : 1;
    }
    return '$count people';
  }

  void _armBonusPattiHide() {
    _bonusPattiHideTimer?.cancel();
    final me = ref.read(userProfileProvider).value?['id']?.toString();
    if (me != null &&
        _bonusPatti?.senderId == me &&
        _repeatGiftSession != null) {
      return;
    }
    _bonusPattiHideTimer = Timer(_repeatGiftVisibleFor, () {
      if (!mounted) return;
      setState(() => _bonusPattiVisible = false);
    });
  }

  void _upsertBonusPattiFromLuckyWin(Map<String, dynamic> luckyMsg) {
    final metadata = luckyMsg['metadata'];
    if (metadata is! Map) return;
    final meta = Map<String, dynamic>.from(metadata);

    final luckyProWon = meta['lucky_pro_bonus_won'] == true;
    final luckyWon = meta['lucky_bonus_won'] == true;
    if (!luckyProWon && !luckyWon) return;

    final userRaw = luckyMsg['user'];
    final user = userRaw is Map
        ? Map<String, dynamic>.from(userRaw)
        : <String, dynamic>{};

    final rewardCoins = luckyProWon
        ? ((meta['lucky_pro_bonus_coins'] as num?)?.toInt() ?? 0)
        : ((meta['lucky_bonus_coins'] as num?)?.toInt() ?? 0);
    if (rewardCoins <= 0) return;

    final senderId =
        luckyMsg['user_id']?.toString() ??
        user['id']?.toString() ??
        meta['sender_id']?.toString() ??
        '';
    if (senderId.isEmpty) return;

    var username =
        meta['sender_username']?.toString() ??
        user['username']?.toString() ??
        '';
    var avatarUrl =
        meta['sender_avatar']?.toString() ?? user['avatar_url']?.toString();
    if (username.isEmpty ||
        username == 'User' ||
        avatarUrl == null ||
        avatarUrl.isEmpty) {
      final me = ref.read(userProfileProvider).value;
      final meId = me?['id']?.toString();
      if (meId != null && meId == senderId) {
        if (username.isEmpty || username == 'User') {
          username = me?['username']?.toString() ?? username;
        }
        if (avatarUrl == null || avatarUrl.isEmpty) {
          avatarUrl = me?['avatar_url']?.toString();
        }
      } else {
        Map<String, dynamic>? found;
        for (final list in [_onlineUsers, _audience, _seats]) {
          for (final m in list) {
            final id = m['id']?.toString() ?? m['user_id']?.toString();
            if (id != senderId) continue;
            found = m;
            break;
          }
          if (found != null) break;
        }
        if (found != null) {
          if (username.isEmpty || username == 'User') {
            username =
                found['username']?.toString() ??
                (found['user'] is Map
                    ? (found['user'] as Map)['username']?.toString()
                    : null) ??
                username;
          }
          if (avatarUrl == null || avatarUrl.isEmpty) {
            avatarUrl =
                found['avatar_url']?.toString() ??
                (found['user'] is Map
                    ? (found['user'] as Map)['avatar_url']?.toString()
                    : null);
          }
        }
      }
    }
    if (username.isEmpty) username = 'User';
    final giftIcon =
        meta['gift_icon']?.toString() ?? meta['icon_url']?.toString();
    final giftQty = ((meta['quantity'] as num?)?.toInt() ?? 1).clamp(1, 9999);
    final multiplier = _resolveLuckyMultiplier(meta, rewardCoins);

    if (!mounted) return;
    setState(() {
      final existing = _bonusPatti;
      if (existing != null &&
          existing.senderId == senderId &&
          _bonusPattiVisible) {
        _bonusPatti = existing.copyWith(
          username: username,
          avatarUrl: avatarUrl,
          giftIcon: (giftIcon != null && giftIcon.isNotEmpty)
              ? giftIcon
              : existing.giftIcon,
          subtitle: _bonusPattiSubtitle(meta),
          bonusCoins: rewardCoins,
          isLuckyPro: luckyProWon || existing.isLuckyPro,
          bonusMultiplier: multiplier,
        );
      } else {
        _bonusPatti = RoomBonusPattiData(
          senderId: senderId,
          username: username,
          avatarUrl: avatarUrl,
          giftIcon: giftIcon,
          subtitle: _bonusPattiSubtitle(meta),
          comboCount: _liveGiftCombo(senderId) > giftQty
              ? _liveGiftCombo(senderId)
              : giftQty,
          bonusCoins: rewardCoins,
          isLuckyPro: luckyProWon,
          bonusMultiplier: multiplier,
        );
      }
      _bonusPattiVisible = true;
    });
    _armBonusPattiHide();
  }

  void _noteGiftCombo(String senderId, int qty) {
    if (senderId.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final prev = _giftComboBySender.remove(senderId);
    var carried = 0;
    if (prev != null &&
        now - prev.atMs <= _repeatGiftVisibleFor.inMilliseconds) {
      carried = prev.total;
    }
    _giftComboBySender[senderId] = (
      total: carried + qty.clamp(1, 9999),
      atMs: now,
    );
    if (_giftComboBySender.length > 64) {
      _giftComboBySender.remove(_giftComboBySender.keys.first);
    }
  }

  /// The sender's combo so far, or 0 once it has gone quiet.
  int _liveGiftCombo(String senderId) {
    final entry = _giftComboBySender[senderId];
    if (entry == null) return 0;
    final age = DateTime.now().millisecondsSinceEpoch - entry.atMs;
    return age <= _repeatGiftVisibleFor.inMilliseconds ? entry.total : 0;
  }

  void _bumpBonusPattiCombo({required String senderId, required int qty}) {
    final current = _bonusPatti;
    if (current == null || !_bonusPattiVisible) return;
    if (current.senderId != senderId) return;
    if (!mounted) return;
    setState(() {
      _bonusPatti = current.copyWith(
        comboCount: current.comboCount + qty.clamp(1, 9999),
      );
    });
    _armBonusPattiHide();
  }

  void _dismissBonusPattiForSender(String senderId) {
    if (_bonusPatti?.senderId != senderId) return;
    _bonusPattiHideTimer?.cancel();
    _bonusPattiHideTimer = null;
    if (!mounted) return;
    setState(() => _bonusPattiVisible = false);
  }

  void _maybeEnqueueLuckyWinFloats(Map<String, dynamic> luckyMsg) {
    unawaited(_enqueueLuckyWinFloatsAsync(luckyMsg));
  }

  Future<void> _enqueueLuckyWinFloatsAsync(
    Map<String, dynamic> luckyMsg,
  ) async {
    final metadata = luckyMsg['metadata'];
    if (metadata is! Map) return;
    final meta = Map<String, dynamic>.from(metadata);

    final luckyProWon = meta['lucky_pro_bonus_won'] == true;
    final luckyWon = meta['lucky_bonus_won'] == true;
    if (!luckyProWon && !luckyWon) return;

    final giftLogId = meta['gift_log_id']?.toString();
    if (giftLogId != null && giftLogId.isNotEmpty) {
      final logKey = 'gift_log_$giftLogId';
      if (_seenLuckyFloatKeys.contains(logKey)) return;
      _seenLuckyFloatKeys.add(logKey);
      _seenBroadcastEventIds.add('gift_log_lucky_$giftLogId');
    }

    final userRaw = luckyMsg['user'];
    final user = userRaw is Map
        ? Map<String, dynamic>.from(userRaw)
        : <String, dynamic>{};

    final rewardCoins = luckyProWon
        ? ((meta['lucky_pro_bonus_coins'] as num?)?.toInt() ?? 0)
        : ((meta['lucky_bonus_coins'] as num?)?.toInt() ?? 0);
    if (rewardCoins <= 0) return;

    _upsertBonusPattiFromLuckyWin(luckyMsg);

    final me = ref.read(userProfileProvider).value?['id']?.toString();
    final winnerId =
        luckyMsg['user_id']?.toString() ?? meta['sender_id']?.toString();
    if (me != null && winnerId == me) {
      ref.invalidate(userProfileProvider);
    }

    final flags = await LuckyRoomSvgaFlagsStore.load(force: false);
    final fanbiEnabled = flags.fanbiEnabled;
    final multiplierMasterEnabled = flags.multiplierEnabled;
    if (!fanbiEnabled && !multiplierMasterEnabled) return;
    if (!mounted) return;

    final eventId = meta['event_id']?.toString();
    final batchId = meta['animation_batch_id']?.toString();
    final senderId =
        luckyMsg['user_id']?.toString() ??
        user['id']?.toString() ??
        meta['sender_id']?.toString() ??
        '';
    final baseId = [
      luckyMsg['id']?.toString(),
      eventId,
      if (eventId == null || eventId.isEmpty) batchId,
      senderId,
      luckyProWon ? 'pro' : 'lucky',
      rewardCoins.toString(),
    ].where((e) => e != null && e.isNotEmpty).join('_');

    if (baseId.isEmpty) return;
    if (_seenLuckyFloatKeys.contains(baseId)) return;

    var multiplier = (meta['bonus_multiplier'] as num?)?.toInt() ?? 0;
    if (multiplier <= 0) {
      final giftValue =
          ((meta['price_coins'] as num?)?.toInt() ?? 0) *
          ((meta['quantity'] as num?)?.toInt() ?? 1);
      multiplier = RoomWinCardUtil.computeBonusMultiplier(
        rewardCoins: rewardCoins,
        giftValue: giftValue,
      );
    }

    Map<String, dynamic>? fanbi;
    if (fanbiEnabled) {
      fanbi = <String, dynamic>{
        'id': '${baseId}_fanbi',
        'baseId': baseId,
        'kind': 'fanbi',
        'username':
            meta['sender_username']?.toString() ??
            user['username']?.toString() ??
            'User',
        'avatarUrl':
            meta['sender_avatar']?.toString() ?? user['avatar_url']?.toString(),
        'rewardCoins': rewardCoins,
      };
    }

    Map<String, dynamic>? multiplierItem;
    if (multiplierMasterEnabled) {
      ref.invalidate(luckyBonusMultiplierSvgasProvider);
      final assets = await ref.read(luckyBonusMultiplierSvgasProvider.future);
      if (!mounted) return;
      final variant = luckyProWon ? 'lucky_pro' : 'lucky';
      final svgaUrl = resolveLuckyBonusMultiplierSvgaUrl(
        assets: assets,
        multiplier: multiplier,
        variant: variant,
      );
      if (svgaUrl != null && svgaUrl.isNotEmpty && multiplier > 0) {
        multiplierItem = {
          'id': '${baseId}_x$multiplier',
          'baseId': baseId,
          'kind': 'multiplier',
          'svgaUrl': svgaUrl,
          'multiplier': multiplier,
        };
      }
    }

    if (!mounted) return;

    if (fanbi != null) {
      _spawnLuckyFloats(baseId: baseId, fanbi: fanbi, multiplier: null);
    }

    if (multiplierItem != null) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _spawnLuckyFloats(
          baseId: '${baseId}_mult',
          fanbi: null,
          multiplier: multiplierItem,
        );
      });
    }
  }

  Map<String, dynamic>? _buildLuckyWinMessageFromGift(
    Map<String, dynamic> message,
  ) {
    final metadata = message['metadata'];
    if (metadata is! Map) return null;
    final luckyBonusWon = metadata['lucky_bonus_won'] == true;
    final luckyProBonusWon = metadata['lucky_pro_bonus_won'] == true;
    if (!luckyBonusWon && !luckyProBonusWon) return null;

    return {
      ...message,
      'type': 'lucky_win',
      'id': 'lucky_${metadata['event_id'] ?? metadata['animation_batch_id']}',
    };
  }

  Future<void> _broadcastRepeatGiftOutcomes({
    required Map<String, dynamic> myUser,
    required List<RoomGiftSendOutcome> outcomes,
    required List<String> targets,
    required String animationBatchId,
    required String giftIcon,
    required int quantity,
    required bool isFullScreen,
    required String svgaUrl,
  }) async {
    final successfulTargets = <String>[];
    final seatGiftDelta = <String, int>{};
    final settledOnGateway = outcomes.any((o) => o.settledOnGateway);
    Map<String, dynamic>? seatTotals;
    for (final o in outcomes) {
      if (o.seatGiftTotals != null) {
        seatTotals = o.seatGiftTotals;
        break;
      }
    }
    if (seatTotals != null) {
      _applySeatGiftTotalsSnapshot(seatTotals);
    }

    for (var i = 0; i < outcomes.length; i++) {
      final outcome = outcomes[i];
      if (!outcome.success) continue;
      successfulTargets.add(targets[i]);
      if (!settledOnGateway && outcome.messageInsert != null) {
        unawaited(
          persistRoomGiftMessage(
            Supabase.instance.client,
            outcome.messageInsert!,
          ),
        );
      }
      final delta = outcome.broadcastPayload?['seat_gift_delta'];
      if (delta is Map) {
        delta.forEach((key, value) {
          seatGiftDelta[key.toString()] =
              (seatGiftDelta[key.toString()] ?? 0) +
              ((value as num?)?.toInt() ?? 0);
        });
      }
    }
    if (successfulTargets.isEmpty) return;

    final giftUiMessages = outcomes
        .where((o) => o.success && o.broadcastPayload?['message'] is Map)
        .map(
          (o) =>
              Map<String, dynamic>.from(o.broadcastPayload!['message'] as Map),
        )
        .toList();
    final luckyMessage = giftUiMessages.where((m) {
      final meta = m['metadata'];
      if (meta is! Map) return false;
      return meta['lucky_bonus_won'] == true ||
          meta['lucky_pro_bonus_won'] == true;
    });
    final firstMessage = luckyMessage.isNotEmpty
        ? luckyMessage.first
        : (giftUiMessages.isNotEmpty ? giftUiMessages.first : null);
    final usesGatewayLucky = outcomes.any((o) => o.usesGatewayLuckyEngine);

    _onGiftBroadcastFromSender({
      'event_id': '${animationBatchId}_settle',
      'animation_batch_id': animationBatchId,
      'sender_id': myUser['id'].toString(),
      'target_ids': successfulTargets,
      'gift_icon': giftIcon,
      'quantity': quantity,
      'is_full_screen': isFullScreen,
      'svga_url': svgaUrl,
      if (usesGatewayLucky) 'lucky_engine': 'gateway',
      if (settledOnGateway) 'settled_on_gateway': true,
      if (seatTotals != null) 'seat_gift_totals': seatTotals,
      if (!settledOnGateway || seatTotals == null)
        'seat_gift_delta': seatGiftDelta,
      if (giftUiMessages.isNotEmpty) 'messages': giftUiMessages,
      if (firstMessage != null) 'message': firstMessage,
    });
  }

  void _triggerGiftAnimation(Map<String, dynamic> msg) {
    final metadata = msg['metadata'];
    if (metadata == null) return;

    final batchId = metadata['animation_batch_id']?.toString() ?? '';
    final targetId = metadata['target_id']?.toString() ?? '';
    final messageId = msg['id']?.toString() ?? '';
    // The batch id, not batch+target: room_gift keys the whole batch by it, and
    // keying this path differently let the same gift fly twice whenever the
    // postgres insert arrived before the socket event.
    final dedupeKey = batchId.isNotEmpty ? batchId : messageId;

    final giftIcon = metadata['gift_icon']?.toString() ?? '';
    final quantity = (metadata['quantity'] as num?)?.toInt() ?? 1;
    final isFullScreen = _truthyBool(metadata['is_full_screen']);
    final svgaUrl = metadata['svga_url']?.toString() ?? '';

    _maybeShowFullScreenGiftAnimation(
      batchId: batchId,
      svgaUrl: svgaUrl,
      isFullScreen: isFullScreen,
      fallbackIconUrl: giftIcon,
    );

    if (dedupeKey.isNotEmpty && _giftFlightController.hasPlayed(dedupeKey)) {
      return;
    }

    final senderId = msg['user_id']?.toString() ?? '';
    _enqueueGiftAnimation(
      dedupeKey: dedupeKey,
      senderId: senderId,
      targetIds: [targetId],
      giftIcon: giftIcon,
      quantity: quantity,
      isFullScreen: isFullScreen,
      svgaUrl: svgaUrl,
      playFullScreenSvga: false,
    );
    _maybeEnqueueBigGiftPattiFromGiftMessage(msg);
  }

  void _showFullScreenGift(String svgaUrl, {String fallbackIconUrl = ''}) {
    final url = svgaUrl.trim();
    if (url.isEmpty) return;
    // This overlay plays on top of everything, including an open game sheet;
    // skip it while a game is open so the game keeps the CPU / GPU (S6).
    if (ref.read(gameOverlayOpenProvider) > 0) return;
    if (_fullScreenGiftShowing) {
      while (_fullScreenGiftQueue.length >= _maxFullScreenGiftQueued) {
        _fullScreenGiftQueue.removeFirst();
      }
      _fullScreenGiftQueue.addLast((svgaUrl: url, iconUrl: fallbackIconUrl));
      return;
    }
    _playFullScreenGiftNow(url, fallbackIconUrl: fallbackIconUrl);
  }

  void _playFullScreenGiftNow(String svgaUrl, {String fallbackIconUrl = ''}) {
    if (!mounted) return;
    _fullScreenGiftShowing = true;
    debugPrint('Showing full screen gift: $svgaUrl');
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return IgnorePointer(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: RoomFullScreenGift(
                    svgaUrl: svgaUrl,
                    fallbackIconUrl: fallbackIconUrl,
                    onFinished: () {
                      _onFullScreenGiftFinished(entry);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    _fullScreenGiftOverlayEntry = entry;
    Overlay.of(context).insert(entry);

    Future.delayed(const Duration(seconds: 15), () {
      if (_fullScreenGiftOverlayEntry == entry) {
        _onFullScreenGiftFinished(entry);
      }
    });
  }

  void _onFullScreenGiftFinished(OverlayEntry entry) {
    if (_fullScreenGiftOverlayEntry == entry) {
      _fullScreenGiftOverlayEntry = null;
      _fullScreenGiftShowing = false;
    }
    if (entry.mounted) entry.remove();
    if (!mounted) return;
    if (_fullScreenGiftShowing) return;
    if (_fullScreenGiftQueue.isEmpty) return;
    final next = _fullScreenGiftQueue.removeFirst();
    _playFullScreenGiftNow(next.svgaUrl, fallbackIconUrl: next.iconUrl);
  }

  Widget _buildChatArea() {
    final bool adminOnlyActive =
        _roomData?['admin_only_chat'] == true && !_canManageRoom;

    if (adminOnlyActive) {
      return SizedBox(
        height: 250,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.purpleAccent.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, color: Colors.purpleAccent, size: 15),
                SizedBox(width: 8),
                Text(
                  'Chat locked — admin & host only',
                  style: TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final List<Map<String, dynamic>> filteredMessages;
    switch (_activeTab) {
      case 'all':
        filteredMessages = _buildAllTabMessages();
        break;
      case 'gift':
        filteredMessages = _messages
            .where((m) => m['type'] == 'gift')
            .toList();
        break;
      default:
        filteredMessages = _messages
            .where(
              (m) =>
                  m['type'] == 'chat' ||
                  m['type'] == 'image' ||
                  _isRoomEntryNotice(m),
            )
            .toList();
    }

    return Container(
      height: 250,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        controller: _chatScrollController,
        itemCount: filteredMessages.length,
        itemBuilder: (context, index) {
          final msg = filteredMessages[index];
          if (msg['type']?.toString() == 'mic_emoji') {
            return const SizedBox.shrink();
          }
          if (msg['type'] == 'system') {
            final content = (msg['content'] ?? '').toString();
            final isEntryNotice = _isRoomEntryNotice(msg);
            final isWelcome = isEntryNotice && !content.contains('Warning!');
            final isSkLiveWelcome = content.contains('Welcome to Livo');
            // An entry notice names whoever just walked in, so tapping it
            // should open that person — previously the name was inert and
            // there was no way to reach their profile from the notice.
            final entryUserId = msg['user_id']?.toString() ?? '';
            return Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: isEntryNotice && entryUserId.isNotEmpty
                    ? () => _showUserMiniProfile(entryUserId)
                    : null,
                child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  content,
                  style: TextStyle(
                    color: isSkLiveWelcome
                        ? const Color(0xFFFFD700)
                        : isEntryNotice
                        ? Colors.white
                        : Colors.orangeAccent,
                    fontSize: isWelcome ? 14 : 12,
                    fontWeight: isWelcome ? FontWeight.w800 : FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                ),
              ),
            );
          }

          if (_activeTab == 'all' && _isWinAnnouncementMessage(msg)) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: msg['type'] == 'global_win'
                    ? RoomWinBonusCard.fromGlobalWin(msg)
                    : RoomWinBonusCard.fromRoomMessage(msg),
              ),
            );
          }

          if (msg['type'] == 'gift') {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [_buildChatBubble(msg), _buildGiftReceiptBubble(msg)],
            );
          }

          return _buildChatBubble(msg);
        },
      ),
    );
  }

  Widget _buildGiftReceiptBubble(Map<String, dynamic> msg) {
    final metadata = msg['metadata'] as Map<String, dynamic>?;
    String receiverName = metadata?['receiver_username'] ?? 'User';
    if (receiverName == 'User' && msg['content'] != null) {
      final String content = msg['content'].toString();
      final parts = content.split(' to ');
      if (parts.length > 1) {
        receiverName = parts.last.trim();
      }
    }

    final int hostReceived =
        (metadata?['host_received'] as num?)?.toInt() ??
        (metadata?['host_share'] as num?)?.toInt() ??
        0;
    final int priceCoins = (metadata?['price_coins'] as num?)?.toInt() ?? 0;
    final int quantity = (metadata?['quantity'] as num?)?.toInt() ?? 1;
    final int totalCoins = priceCoins * quantity;
    final bool luckyBonusWon = metadata?['lucky_bonus_won'] == true;
    final bool showLegacyLuckyBanner = false;
    final int luckyBonusCoins =
        (metadata?['lucky_bonus_coins'] as num?)?.toInt() ?? 0;

    final String receiverId = metadata?['target_id']?.toString() ?? '';
    String? receiverAvatar;
    if (receiverId.isNotEmpty) {
      final onlineUser = _onlineUsers.firstWhere(
        (u) => u['id']?.toString() == receiverId,
        orElse: () => {},
      );
      if (onlineUser.isNotEmpty && onlineUser['avatar_url'] != null) {
        receiverAvatar = onlineUser['avatar_url'];
      } else {
        for (var seat in _seats) {
          if (seat['user'] != null &&
              seat['user']['id']?.toString() == receiverId) {
            receiverAvatar = seat['user']['avatar_url'];
            break;
          }
        }
      }
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: 4,
              bottom: showLegacyLuckyBanner ? 2 : 4,
              left: 10,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1035).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white10,
                  ),
                  child: ClipOval(
                    child: receiverAvatar != null && receiverAvatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: receiverAvatar,
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
                          )
                        : const Icon(
                            Icons.person,
                            size: 10,
                            color: Colors.white24,
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: receiverName,
                          style: const TextStyle(
                            color: Colors.yellowAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: ' received '),
                        TextSpan(
                          text: NumberFormatter.format(hostReceived),
                          style: const TextStyle(
                            color: Colors.pinkAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: ' Diamonds'),
                        if (metadata?['is_lucky_gift'] == true)
                          const TextSpan(
                            text: ' (Lucky)',
                            style: TextStyle(color: Colors.amber, fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showLegacyLuckyBanner)
            Container(
              margin: const EdgeInsets.only(bottom: 4, left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade700.withValues(alpha: 0.9),
                    Colors.orange.shade800.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🎉 Sender lucky bonus: $luckyBonusCoins coins (more than $totalCoins gift!)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// One line per gift: "sent Rose to Ann", "sent Rose x5 to Ann", and for a
  /// settled lucky roll the win rides on the same line instead of a second
  /// comment. Null when the row predates the metadata this needs.
  String? _giftChatLine(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    final giftName = metadata['gift_name']?.toString() ?? '';
    final receiver = metadata['receiver_username']?.toString() ?? '';
    if (giftName.isEmpty || receiver.isEmpty) return null;

    final quantity = (metadata['quantity'] as num?)?.toInt() ?? 1;
    final qtySuffix = quantity > 1 ? ' x$quantity' : '';
    final line = 'sent $giftName$qtySuffix to $receiver';

    final luckyProWon = metadata['lucky_pro_bonus_won'] == true;
    final luckyWon = metadata['lucky_bonus_won'] == true;
    if (!luckyProWon && !luckyWon) return line;

    final coins = luckyProWon
        ? ((metadata['lucky_pro_bonus_coins'] as num?)?.toInt() ?? 0)
        : ((metadata['lucky_bonus_coins'] as num?)?.toInt() ?? 0);
    if (coins <= 0) return line;
    final multiplier = _resolveLuckyMultiplier(metadata, coins);
    final label = luckyProWon ? 'Lucky Pro' : 'Lucky';
    return '$line — $label x$multiplier '
        '+${NumberFormatter.format(coins)} coins';
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final userId = msg['user_id']?.toString() ?? '';
    final styleIndex = userId.hashCode.abs() % 4;

    final List<Color> bgColors = [
      const Color(0xFF4A148C).withValues(alpha: 0.5),
      const Color(0xFF004D40).withValues(alpha: 0.5),
      const Color(0xFFBF360C).withValues(alpha: 0.5),
      const Color(0xFF1A237E).withValues(alpha: 0.5),
    ];

    final List<Color> borderColors = [
      Colors.purpleAccent,
      Colors.tealAccent,
      Colors.orangeAccent,
      Colors.indigoAccent,
    ];

    final List<String> tempIcons = [
      'https://pbobnvkscssgfpynmdhl.supabase.co/storage/v1/object/public/app_assets/charm/charm%20b1.png',
      'https://pbobnvkscssgfpynmdhl.supabase.co/storage/v1/object/public/app_assets/charm/charm%20b2.png',
      'https://pbobnvkscssgfpynmdhl.supabase.co/storage/v1/object/public/app_assets/charm/charm%20b3.png',
      'https://pbobnvkscssgfpynmdhl.supabase.co/storage/v1/object/public/app_assets/charm/charm%20b4.png',
    ];

    String resolvedUsername = 'User';
    String? resolvedAvatar;
    if (msg['user'] != null) {
      resolvedUsername = msg['user']['username'] ?? 'User';
      resolvedAvatar = msg['user']['avatar_url'];
    } else {
      final onlineUser = _onlineUsers.firstWhere(
        (u) => u['id']?.toString() == userId,
        orElse: () => {},
      );
      if (onlineUser.isNotEmpty) {
        resolvedUsername = onlineUser['username'] ?? 'User';
        resolvedAvatar = onlineUser['avatar_url'];
      } else {
        for (var seat in _seats) {
          if (seat['user'] != null &&
              seat['user']['id']?.toString() == userId) {
            resolvedUsername = seat['user']['username'] ?? 'User';
            resolvedAvatar = seat['user']['avatar_url'];
            break;
          }
        }
      }
    }

    String displayContent = msg['content'] ?? '';
    if (msg['type'] == 'gift') {
      final metadata = msg['metadata'] as Map<String, dynamic>?;
      final int priceCoins = (metadata?['price_coins'] as num?)?.toInt() ?? 0;
      final int quantity = (metadata?['quantity'] as num?)?.toInt() ?? 1;
      final int totalCoins = priceCoins * quantity;
      displayContent = _giftChatLine(metadata) ?? displayContent;
      if (totalCoins > 0) {
        displayContent += ' (${NumberFormatter.format(totalCoins)} Coins)';
      }
    }

    final meta = msg['metadata'] is Map
        ? Map<String, dynamic>.from(msg['metadata'] as Map)
        : <String, dynamic>{};
    final sharedImageUrl = meta['image_url']?.toString();
    final localImagePath = meta['local_path']?.toString();
    final isUploading = meta['uploading'] == true;
    final frame = _resolveBubbleFrame(userId: userId, meta: meta);
    final hasNineSlice = frame.frameUrl != null && frame.frameUrl!.isNotEmpty;
    final cornerIcon =
        frame.iconUrl ?? (hasNineSlice ? null : tempIcons[styleIndex]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DynamicChatBubble(
        userId: msg['user_id'],
        username: resolvedUsername,
        content: displayContent,
        iconUrl: cornerIcon,
        frameUrl: frame.frameUrl,
        frameSvgaUrl: frame.svgaUrl,
        bgColor: bgColors[styleIndex],
        borderColor: borderColors[styleIndex],
        senderAvatar: resolvedAvatar,
        imageUrl: sharedImageUrl,
        localImagePath: sharedImageUrl == null ? localImagePath : null,
        isUploadingImage: isUploading,
        onImageTap: sharedImageUrl != null
            ? () => _saveRoomImageToGallery(sharedImageUrl)
            : null,
      ),
    );
  }

  Map<String, dynamic> _bubbleMetaFromAsset(UserAsset? asset) {
    if (asset == null) return const {};
    final url = asset.imageUrl?.trim() ?? '';
    if (url.isEmpty) return const {};
    final svga = asset.svgaUrl?.trim() ?? '';
    if (!isNineSliceChatBubble(name: asset.name, imageUrl: url)) {
      return {
        'bubble_icon': url,
        if (asset.name.trim().isNotEmpty) 'bubble_name': asset.name.trim(),
      };
    }
    return {
      'bubble_url': url,
      if (svga.isNotEmpty) 'bubble_svga': svga,
      if (asset.name.trim().isNotEmpty) 'bubble_name': asset.name.trim(),
    };
  }

  Future<Map<String, dynamic>> _equippedBubbleMetadataAsync(
    String? userId,
  ) async {
    if (userId == null || userId.isEmpty) return const {};
    try {
      final asset = await ref.read(equippedBubbleProvider(userId).future);
      return _bubbleMetaFromAsset(asset);
    } catch (_) {
      return _bubbleMetaFromAsset(
        ref.read(equippedBubbleProvider(userId)).valueOrNull,
      );
    }
  }

  ({String? frameUrl, String? iconUrl, String? svgaUrl}) _resolveBubbleFrame({
    required String userId,
    required Map<String, dynamic> meta,
  }) {
    String? frameUrl = meta['bubble_url']?.toString().trim();
    String? iconUrl = meta['bubble_icon']?.toString().trim();
    String? svgaUrl = meta['bubble_svga']?.toString().trim();
    final metaName = meta['bubble_name']?.toString();

    final asset = userId.isEmpty
        ? null
        : ref.watch(equippedBubbleProvider(userId)).valueOrNull;

    if ((frameUrl == null || frameUrl.isEmpty) && asset != null) {
      final url = asset.imageUrl?.trim() ?? '';
      if (url.isNotEmpty) {
        if (isNineSliceChatBubble(name: asset.name, imageUrl: url) ||
            isNineSliceChatBubble(name: metaName, imageUrl: url)) {
          frameUrl = url;
          final s = asset.svgaUrl?.trim() ?? '';
          if (s.isNotEmpty) svgaUrl ??= s;
        } else {
          iconUrl ??= url;
        }
      }
    }

    if (frameUrl != null &&
        frameUrl.isNotEmpty &&
        !isNineSliceChatBubble(name: metaName, imageUrl: frameUrl)) {
      iconUrl ??= frameUrl;
      frameUrl = null;
    }

    return (frameUrl: frameUrl, iconUrl: iconUrl, svgaUrl: svgaUrl);
  }

  Widget _buildBottomToolbar() {
    final unreadDmCount = friendMessagesUnreadCount(ref);

    return ValueListenableBuilder<bool>(
      valueListenable: _chatBarOpen,
      builder: (context, chatOpen, _) => _bottomToolbarBody(
        showExpandedChat: chatOpen,
        unreadDmCount: unreadDmCount,
      ),
    );
  }

  Widget _bottomToolbarBody({
    required bool showExpandedChat,
    required int unreadDmCount,
  }) {
    return Container(
      key: _bottomToolbarKey,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black45],
        ),
      ),
      child: showExpandedChat
          ? _buildExpandedRoomChatBar()
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RoomToolbarButton(
                  assetPath: 'assets/room/toolbar/chat.webp',
                  onTap: _expandRoomChat,
                ),
                if (_mySeatIndex != null) ...[
                  RoomToolbarButton(
                    icon: Iconsax.emoji_happy,
                    onTap: _showMicEmojiSheet,
                  ),
                  RoomToolbarButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic_none,
                    iconColor: _isMuted
                        ? Colors.redAccent
                        : const Color(0xFFF5F0E6),
                    onTap: _toggleMic,
                  ),
                ],
                RoomToolbarButton(
                  icon: _roomAudioMuted ? Icons.volume_off : Icons.volume_up,
                  iconColor: _roomAudioMuted
                      ? Colors.redAccent
                      : const Color(0xFFF5F0E6),
                  onTap: _toggleRoomAudioMute,
                  onLongPress: _showSoundSheet,
                ),
                RoomToolbarButton(
                  icon: Icons.grid_view_rounded,
                  onTap: _showToolsSheet,
                ),
                RoomToolbarButton(
                  assetPath: 'assets/room/toolbar/mail.webp',
                  style: RoomToolbarButtonStyle.badge,
                  badgeCount: unreadDmCount > 0 ? unreadDmCount : null,
                  onTap: () => RoomPrivateMessagesSheet.show(context),
                ),
                RoomToolbarButton(
                  assetPath: 'assets/room/toolbar/game.webp',
                  style: RoomToolbarButtonStyle.game,
                  size: 36,
                  onTap: _showGamesMenu,
                ),
                RoomToolbarButton(
                  assetPath: 'assets/room/toolbar/gift.webp',
                  style: RoomToolbarButtonStyle.gift,
                  size: 38,
                  onTap: _showGiftSheet,
                ),
              ],
            ),
    );
  }

  void _expandRoomChat() {
    if (_roomData?['admin_only_chat'] == true && !_canManageRoom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admin/host can chat in this room'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _isRoomChatExpanded = true;
    _chatBarOpen.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chatFocusNode.requestFocus();
    });
  }

  void _collapseRoomChat() {
    _chatFocusNode.unfocus();
    _isRoomChatExpanded = false;
    _chatBarOpen.value = false;
  }

  Widget _buildExpandedRoomChatBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: _collapseRoomChat,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.close, color: Colors.white70, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.yellowAccent.withValues(alpha: 0.5),
              ),
            ),
            child: TextField(
              controller: _messageController,
              focusNode: _chatFocusNode,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Say Hi',
                hintStyle: TextStyle(color: Colors.white60, fontSize: 13),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showRoomImageSourceSheet,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            child: const Icon(Iconsax.gallery, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.yellowAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_upward,
              color: Colors.black,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  void _showToolsSheet() {
    unawaited(OrbitVoiceSessionService.ensureDenoisePrefLoaded());
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141418),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            final denoiseOn =
                OrbitVoiceSessionService.noiseCancellationPrefEnabled;
            return Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, bottomInset + 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const Text(
                    'Interactive play',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildInteractivePlayItem(
                        'assets/room/lucky_bag.webp',
                        context.l10n.room_luckyBag,
                        onTap: () {
                          Navigator.pop(context);
                          LuckyBagSheet.show(
                            context,
                            roomId: widget.room['id'].toString(),
                          );
                        },
                      ),
                      if (_canManageRoom) ...[
                        const SizedBox(width: 8),
                        _buildInteractivePlayItem(
                          'assets/room/pk_team.webp',
                          context.l10n.room_teamPk,
                          onTap: () {
                            Navigator.pop(context);
                            _showTeamPkSettingSheet();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildInteractivePlayItem(
                          'assets/room/pk.webp',
                          context.l10n.room_pk,
                          onTap: () {
                            Navigator.pop(context);
                            _showPkSettingSheet();
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Room tool',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 6,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 4,
                    childAspectRatio: 0.85,
                    children: [
                      _buildToolItem(
                        Iconsax.send_1,
                        context.l10n.room_invite,
                        onTap: () {
                          Navigator.pop(context);
                          _showShareRoomSheet();
                        },
                      ),
                      _buildToolItem(
                        Icons.volume_up,
                        'Sound',
                        onTap: _showSoundSheet,
                      ),
                      _buildToolItem(
                        denoiseOn
                            ? Icons.noise_aware_rounded
                            : Icons.hearing_disabled_rounded,
                        denoiseOn ? 'Denoiser' : 'Denoiser off',
                        color: denoiseOn ? Colors.greenAccent : Colors.white54,
                        onTap: () async {
                          final next = !denoiseOn;
                          await OrbitVoiceSessionService.setNoiseCancellation(
                            next,
                          );
                          if (!context.mounted) return;
                          setSheet(() {});
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                next
                                    ? 'Denoiser on'
                                    : 'Denoiser off — try speaking',
                              ),
                              duration: const Duration(seconds: 2),
                              backgroundColor: const Color(0xFF2A1450),
                            ),
                          );
                        },
                      ),
                      if (_canUseRoomAudio)
                        _buildToolItem(
                          Icons.music_note_rounded,
                          'Room Audio',
                          color: Colors.cyanAccent,
                          onTap: () {
                            Navigator.pop(context);
                            RoomSharedAudioSheet.show(
                              context,
                              controller: _sharedAudioSync,
                              queue: _sharedAudioQueue,
                              roomId: widget.room['id'].toString(),
                            );
                          },
                        ),
                      if (_canManageRoom) ...[
                        if (_isRoomHost || _isSuperAdmin) ...[
                          _buildToolItem(
                            Icons.grid_on,
                            'Mic mode',
                            onTap: _showRoomModeSheet,
                          ),
                          _buildToolItem(
                            Icons.settings,
                            context.l10n.room_settings,
                            color: Colors.greenAccent,
                            onTap: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RoomInfoScreen(
                                    roomId: widget.room['id'].toString(),
                                  ),
                                ),
                              );
                              _fetchRoomDetails();
                            },
                          ),
                          _buildToolItem(
                            Iconsax.gift,
                            'Charm',
                            color: AppColors.cpHeartPink,
                            onTap: () {
                              Navigator.pop(context);
                              _showGiftSheet();
                            },
                          ),
                        ],
                        _buildToolItem(
                          Icons.delete_sweep_outlined,
                          'Clear chat',
                          color: Colors.lightBlueAccent,
                          onTap: () {
                            Navigator.pop(context);
                            _confirmClearChat();
                          },
                        ),
                        if (_isRoomHost || _isSuperAdmin) ...[
                          _buildToolItem(
                            Icons.image_outlined,
                            'Background',
                            color: Colors.blueAccent,
                            onTap: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RoomDecorationScreen(
                                    roomId: widget.room['id'],
                                    currentDecorationId:
                                        _roomData?['decoration_id'],
                                    currentBackgroundUrl:
                                        _roomData?['background_url'],
                                  ),
                                ),
                              );
                              _fetchRoomDetails();
                            },
                          ),
                          _buildToolItem(
                            Icons.auto_fix_high,
                            'Effect',
                            color: Colors.purpleAccent,
                            onTap: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RoomDecorationScreen(
                                    roomId: widget.room['id'],
                                    currentDecorationId:
                                        _roomData?['decoration_id'],
                                    currentBackgroundUrl:
                                        _roomData?['background_url'],
                                  ),
                                ),
                              );
                              _fetchRoomDetails();
                            },
                          ),
                          _buildToolItem(
                            Icons.play_circle_fill,
                            context.l10n.room_youtube,
                            color: Colors.red,
                            onTap: _showYoutubeSearchDialog,
                          ),
                          _buildToolItem(
                            Icons.sports_esports,
                            'Game mode',
                            color: Colors.deepPurpleAccent,
                            onTap: () {
                              Navigator.pop(context);
                              _showGamesMenu();
                            },
                          ),
                          _buildToolItem(
                            roomIsLocked(_roomData ?? widget.room)
                                ? Icons.lock
                                : Icons.lock_open,
                            roomIsLocked(_roomData ?? widget.room)
                                ? 'Unlock'
                                : 'Room Lock',
                            color: roomIsLocked(_roomData ?? widget.room)
                                ? Colors.amber
                                : Colors.white70,
                            onTap: () async {
                              Navigator.pop(context);
                              if (!mounted) return;
                              await _toggleRoomLock();
                            },
                          ),
                          _buildToolItem(
                            _roomData?['admin_only_chat'] == true
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            _roomData?['admin_only_chat'] == true
                                ? 'Chat lock'
                                : 'Open chat',
                            color: _roomData?['admin_only_chat'] == true
                                ? Colors.blueAccent
                                : Colors.white70,
                            onTap: () {
                              Navigator.pop(context);
                              _toggleAdminOnlyChat();
                            },
                          ),
                        ],
                      ],
                      _buildToolItem(
                        Icons.report_problem,
                        'Report',
                        color: Colors.redAccent,
                        onTap: _showReportSheet,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmClearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A2E),
        title: const Text(
          'Clear Chat?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'All current messages will be hidden for everyone. New messages will still appear.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final clearedAt = DateTime.now().toUtc().toIso8601String();
      await Supabase.instance.client.rpc(
        'clear_room_chat',
        params: {'p_room_id': widget.room['id']},
      );
      if (mounted) {
        setState(() {
          _roomData?['chat_cleared_at'] = clearedAt;
        });
        _clearChatMessages();
        unawaited(_broadcastRoomMeta({'chat_cleared_at': clearedAt}));
        _addSystemMessage('Chat has been cleared by admin.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear chat: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _toggleRoomLock() async {
    if (!_isRoomHost && !_isSuperAdmin) return;
    final roomId = widget.room['id'].toString();
    final data = _roomData ?? widget.room;
    final currentlyLocked = roomIsLocked(data);

    try {
      if (currentlyLocked) {
        await Supabase.instance.client
            .from('rooms')
            .update({'is_locked': false})
            .eq('id', roomId);
        if (!mounted) return;
        setState(() {
          _roomData ??= Map<String, dynamic>.from(widget.room);
          _roomData!['is_locked'] = false;
        });
        unawaited(_broadcastRoomMeta({'is_locked': false}));
        _addSystemMessage('Room unlocked — anyone can join.');
        return;
      }

      var password = data['room_password']?.toString().trim() ?? '';
      if (password.length < 4) {
        final setPass = await showRoomLockPasswordDialog(
          context,
          title: 'Set Room Lock Password',
          confirmLabel: 'Lock',
        );
        if (setPass == null || setPass.length < 4) return;
        password = setPass;
      }

      await Supabase.instance.client
          .from('rooms')
          .update({'room_password': password, 'is_locked': true})
          .eq('id', roomId);

      if (!mounted) return;
      setState(() {
        _roomData ??= Map<String, dynamic>.from(widget.room);
        _roomData!['room_password'] = password;
        _roomData!['is_locked'] = true;
      });
      unawaited(_broadcastRoomMeta({'is_locked': true}));
      _addSystemMessage('Room locked — password required to join.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update room lock: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _toggleAdminOnlyChat() async {
    if (!_isRoomHost && !_isSuperAdmin) return;
    final current = _roomData?['admin_only_chat'] == true;
    final newValue = !current;
    try {
      await Supabase.instance.client
          .from('rooms')
          .update({'admin_only_chat': newValue})
          .eq('id', widget.room['id']);
      if (mounted) {
        setState(() => _roomData?['admin_only_chat'] = newValue);
        unawaited(_broadcastRoomMeta({'admin_only_chat': newValue}));
        _addSystemMessage(
          newValue
              ? 'Chat locked — only admins & host can send messages.'
              : 'Chat unlocked — everyone can send messages.',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showTeamPkSettingSheet() {
    final roomId = widget.room['id'].toString();
    TeamPkSettingSheet.show(
      context,
      roomId: roomId,
      onStarted: () {
        ref.invalidate(roomPkSessionProvider(roomId));
        _fetchRoomDetails();
        _fetchSeats();
      },
    );
  }

  Map<String, dynamic>? _seatUserAt(int index) {
    if (index < 0 || index >= _seats.length) return null;
    final user = _seats[index]['user'];
    if (user is Map<String, dynamic>) return user;
    return null;
  }

  void _showPkSettingSheet() {
    final roomId = widget.room['id'].toString();
    PkSettingSheet.show(
      context,
      roomId: roomId,
      onStarted: () {
        ref.invalidate(roomPkSessionProvider(roomId));
        _fetchRoomDetails();
        _fetchSeats();
      },
    );
  }

  void _showRoomModeSheet() {
    if (!_isRoomHost && !_isSuperAdmin) return;
    final currentRoom = _roomData ?? widget.room;
    final currentLayout = _resolveRoomMicLayout(
      micCount: currentRoom['mic_count'] as int?,
      partyMode: currentRoom['party_mode']?.toString(),
    );
    var selectedLayout = currentLayout;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            final cardWidth =
                (MediaQuery.of(context).size.width - 16 * 2 - 10) / 2;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset + 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const Text(
                    'Room Type',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Seat layout matches the live room. Switching may move users.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                    ),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _roomMicLayouts.map((opt) {
                          final isSelected = selectedLayout.id == opt.id;
                          return GestureDetector(
                            onTap: () =>
                                setModalState(() => selectedLayout = opt),
                            child: Container(
                              width: cardWidth,
                              height: 128,
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF242428),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFF4D8D)
                                      : Colors.white12,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF121214),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: _buildMicLayoutPreview(
                                          opt,
                                          selected: isSelected,
                                          maxWidth: cardWidth - 28,
                                          maxHeight: 54,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    opt.title,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFFFF4D8D)
                                          : Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    opt.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => _updateRoomMode(
                        selectedLayout.micCount,
                        selectedLayout.id,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D8D),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
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

  Widget _buildMicLayoutPreview(
    _RoomMicLayout layout, {
    required bool selected,
    required double maxWidth,
    double maxHeight = 54,
  }) {
    final columns = layout.maxColumns;
    final rows = layout.rows.length;
    const gap = 2.0;
    final byWidth = (maxWidth - gap * (columns - 1)) / columns;
    final byHeight = (maxHeight - gap * (rows - 1)) / rows;
    final seatSize = (byWidth < byHeight ? byWidth : byHeight).clamp(9.0, 14.0);

    var seatNo = 0;
    return SizedBox(
      width: columns * seatSize + gap * (columns - 1),
      height: rows * seatSize + gap * (rows - 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var r = 0; r < layout.rows.length; r++) ...[
            if (r > 0) const SizedBox(height: gap),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var c = 0; c < layout.rows[r]; c++) ...[
                  if (c > 0) const SizedBox(width: gap),
                  Builder(
                    builder: (_) {
                      final index = seatNo++;
                      final isOwner = layout.ownerSeatIndex == index;
                      return Container(
                        width: seatSize,
                        height: seatSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isOwner
                                ? const [Color(0xFFFFB4D0), Color(0xFFFF4D8D)]
                                : selected
                                ? const [Color(0xFFB388FF), Color(0xFFFF4D8D)]
                                : const [Color(0xFF7A6A9A), Color(0xFF9A5A7A)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFF4D8D,
                              ).withValues(alpha: selected ? 0.35 : 0.12),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: isOwner
                            ? Image.asset(
                                'assets/room/owner_chair_crown.webp',
                                width: seatSize * 0.92,
                                height: seatSize * 0.92,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.event_seat_rounded,
                                  size: (seatSize * 0.62).clamp(7.0, 11.0),
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: (seatSize * 0.42).clamp(6.0, 9.0),
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showReportSheet() {
    final reasons = [
      'Harassment or Abuse',
      'Spam or Scams',
      'Inappropriate Content',
      'Child Safety',
      'Hate Speech',
      'Illegal Activities',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Report Room',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select a reason for reporting this room:',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: reasons.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        reasons[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white24,
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        _submitReport(reasons[index]);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReport(String reason) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) {
      devLog('REPORT_DEBUG: User is null');
      return;
    }

    devLog('REPORT_DEBUG: Submitting report for reason: $reason');

    try {
      final messenger = ScaffoldMessenger.of(context);

      await Supabase.instance.client
          .from('room_reports')
          .insert({
            'room_id': widget.room['id'],
            'reporter_id': user['id'],
            'reason': reason,
            'created_at': DateTime.now().toIso8601String(),
          })
          .timeout(const Duration(seconds: 2));

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted successfully. Thank you for keeping Livo safe!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      devLog('REPORT_ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your report has been received.'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    }
  }

  Future<void> _toggleRoomAudioMute() async {
    final mute = !_roomAudioMuted;
    setState(() => _roomAudioMuted = mute);

    try {
      await OrbitVoiceSessionService.setRemoteAudioMuted(mute);
    } catch (e) {
      debugPrint('[ORBIT] toggle room mute: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mute ? 'Room sound off' : 'Room sound on'),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  void _showSoundSheet() {
    unawaited(OrbitVoiceSessionService.ensureDenoisePrefLoaded());
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sound Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: Icon(
                        _audioRouteToSpeaker
                            ? Icons.volume_up
                            : Icons.phone_android,
                        color: Colors.yellowAccent,
                      ),
                      title: const Text(
                        'Output Device',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _audioRouteToSpeaker ? 'Speaker' : 'Earpiece',
                        style: const TextStyle(color: Colors.white38),
                      ),
                      trailing: Switch(
                        value: _audioRouteToSpeaker,
                        activeThumbColor: Colors.yellowAccent,
                        onChanged: (val) {
                          setModalState(() => _audioRouteToSpeaker = val);
                          if (mounted) setState(() {});
                          unawaited(OrbitVoiceSessionService.setSpeakerOn(val));
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: Icon(
                        OrbitVoiceSessionService.noiseCancellationPrefEnabled
                            ? Icons.noise_aware_rounded
                            : Icons.hearing_disabled_rounded,
                        color: Colors.yellowAccent,
                      ),
                      title: const Text(
                        'Denoiser',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        OrbitVoiceSessionService.noiseCancellationPrefEnabled
                            ? 'Noise cancel on'
                            : 'Off — raw mic (try if voice is silent)',
                        style: const TextStyle(color: Colors.white38),
                      ),
                      trailing: Switch(
                        value: OrbitVoiceSessionService
                            .noiseCancellationPrefEnabled,
                        activeThumbColor: Colors.yellowAccent,
                        onChanged: (val) async {
                          await OrbitVoiceSessionService.setNoiseCancellation(
                            val,
                          );
                          if (!context.mounted) return;
                          setModalState(() {});
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text(
                          'Room Volume',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          '${_roomPlayVolume.round()}%',
                          style: const TextStyle(
                            color: Colors.yellowAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Slider(
                    value: _roomPlayVolume.clamp(0, 200),
                    min: 0,
                    max: 200,
                    divisions: 40,
                    label: '${_roomPlayVolume.round()}%',
                    activeColor: Colors.yellowAccent,
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setModalState(() => _roomPlayVolume = val);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateRoomMode(int micCount, String mode) async {
    devLog('ATTEMPTING_ROOM_UPDATE: micCount=$micCount, mode=$mode');
    try {
      final roomId = _roomData?['id'] ?? widget.room['id'];
      final response = await Supabase.instance.client
          .from('rooms')
          .update({'mic_count': micCount, 'party_mode': mode})
          .eq('id', roomId)
          .select();

      devLog('SUPABASE_RESPONSE: $response');

      if (response.isEmpty) {
        _addSystemMessage('Update failed: No rows affected. Check columns.');
      } else {
        _addSystemMessage('Room updated to $micCount seats!');
        if (mounted) {
          setState(() {
            _roomData!['mic_count'] = micCount;
            _roomData!['party_mode'] = mode;
          });
          unawaited(
            _broadcastRoomMeta({'mic_count': micCount, 'party_mode': mode}),
          );
          _initSeats();
        }
      }

      if (mounted) Navigator.pop(context);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _addSystemMessage('Error updating room: $e');
      devLog('Room Update Error: $e');
    }
  }

  Widget _buildSeatMicIndicator(String userId, bool isMuted) {
    final uid = userId.toString();
    final isSpeaking = _isSeatSpeaking(uid);

    if (isMuted) {
      return SizedBox(
        width: 26,
        height: 26,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_off, color: Colors.white, size: 10),
          ),
        ),
      );
    }

    if (isSpeaking) {
      return SizedBox(
        width: 26,
        height: 26,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 0.5),
            ),
            child: const Icon(Icons.mic, color: Colors.black, size: 10),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: 26,
        height: 26,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 0.5),
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 10),
          ),
        ),
      );
    }
  }

  Widget _buildInteractivePlayItem(
    String assetPath,
    String label, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.sports_esports,
                color: Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem(
    dynamic iconOrPath,
    String label, {
    Color? color,
    VoidCallback? onTap,
  }) {
    final accent = color ?? Colors.white70;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            clipBehavior: Clip.antiAlias,
            child: iconOrPath is IconData
                ? Center(child: Icon(iconOrPath, color: accent, size: 15))
                : (iconOrPath as String).startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: iconOrPath,
                    fit: BoxFit.cover,
                    width: 32,
                    height: 32,
                    placeholder: (context, url) => const Center(
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.gamepad,
                      color: Colors.white70,
                      size: 15,
                    ),
                  )
                : Image.asset(
                    iconOrPath,
                    fit: BoxFit.cover,
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.directions_car,
                      color: Colors.orangeAccent,
                      size: 15,
                    ),
                  ),
          ),
          const SizedBox(height: 3),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 8,
                height: 1.1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatGiftFloatingButton() {
    final session = _repeatGiftSession!;
    return RoomGiftComboButton(
      giftIcon: session.giftIcon,
      count: _repeatComboCount < 1 ? 1 : _repeatComboCount,
      tick: _repeatComboTick.value,
      window: _repeatGiftVisibleFor,
      onTap: _enqueueRepeatGift,
      onLongPress: _clearRepeatGiftSession,
    );
  }

  void _launchGameFromConfig(Map<String, dynamic> game) {
    final gameId = game['id']?.toString() ?? '';
    if (gameId.isNotEmpty) {
      unawaited(HiveCacheService.pushRecentGameId(gameId));
    }

    if (game['maintenance_mode'] == true) {
      final msg = game['maintenance_message']?.toString().trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (msg != null && msg.isNotEmpty)
                ? msg
                : 'This game is under maintenance. Please try again later.',
          ),
        ),
      );
      return;
    }

    final baseUrl = (game['game_url'] ?? 'https://sk-live-games.vercel.app/')
        .toString();
    if (isWaveGameConfig(game) || isWaveGameUrl(baseUrl)) {
      final rawPct = game['webview_height_percent'];
      final pct = rawPct is num
          ? rawPct.toDouble()
          : double.tryParse(rawPct?.toString() ?? '');
      launchH5Game(
        context,
        name: (game['display_name'] ?? game['name'] ?? 'Game').toString(),
        gameUrl: baseUrl,
        gameConfig: game,
        heightPercent: pct,
        roomId: widget.room['id']?.toString(),
      );
      return;
    }
    final tulasi = isTulasiGameConfig(game) || isTulasiGameUrl(baseUrl);
    final baishun =
        !tulasi &&
        (isBaishunGameConfig(game) ||
            isBaishunGameUrl(baseUrl) ||
            isBaishunGameUrl(
              resolveBaishunGameUrl(game, fallbackUrl: baseUrl),
            ));
    late final String finalUrl;
    if (tulasi) {
      final token = currentSkAccessToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to play this game.')),
        );
        return;
      }
      finalUrl = buildTulasiLaunchUrl(
        baseUrl,
        token: token,
        lang: tulasiLangCode(context),
        isLandscape: isTulasiLandscape(game),
      );
    } else if (baishun) {
      final token = currentSkAccessToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to play this game.')),
        );
        return;
      }
      finalUrl = resolveBaishunGameUrl(game, fallbackUrl: baseUrl);
      if (finalUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game URL is not configured.')),
        );
        return;
      }
    } else {
      final uri = Uri.parse(baseUrl);
      finalUrl = uri
          .replace(
            queryParameters: {
              ...uri.queryParameters,
              'gateway': AppConstants.realtimeGatewayUrl,
            },
          )
          .toString();
    }

    _openGameWebView(finalUrl, game);
  }

  Future<void> _showGamesMenu() async {
    if (!mounted) return;
    // The sheet is inserted before any Hive read or catalog request. A fetch
    // started in this same turn runs its synchronous prefix first and is
    // what made the icon feel dead for a second.
    final selectedFuture = showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        // DraggableScrollableSheet, not a plain sized child: it owns the list's
        // scroll controller, so a downward drag moves the sheet with the finger
        // once the list is at its top and lets go of it again on the way back
        // up — the Instagram-style handoff. A plain modal sheet loses that drag
        // to the list entirely, which is why only a barrier tap closed it.
        final extent = RoomGamesSheet.heightFraction(sheetContext);
        return DraggableScrollableSheet(
          initialChildSize: extent,
          minChildSize: extent * 0.5,
          maxChildSize: extent,
          expand: false,
          snap: true,
          snapSizes: [extent],
          // Dragged down to minChildSize, close the route instead of parking
          // the sheet half-open.
          shouldCloseOnMinExtent: true,
          builder: (context, scrollController) => ValueListenableBuilder<int>(
            valueListenable: _gamesRev,
            builder: (context, _, _) => RoomGamesSheet(
              games: _activeGames,
              recentGames: HiveCacheService.resolveRecentGames(_activeGames),
              scrollController: scrollController,
              onGameTap: (game) {
                Navigator.pop(sheetContext, game);
              },
            ),
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_fetchActiveGames());
    });
    final selected = await selectedFuture;
    if (!mounted || selected == null) return;
    _launchGameFromConfig(selected);
  }

  void _openGameWebView(String url, [Map<String, dynamic>? game]) {
    final tulasi = isTulasiGameConfig(game) || isTulasiGameUrl(url);
    final baishun =
        !tulasi &&
        (isBaishunGameConfig(game) ||
            isBaishunGameUrl(url) ||
            isBaishunGameUrl(resolveBaishunGameUrl(game, fallbackUrl: url)));
    final landscape =
        (tulasi && isTulasiLandscape(game)) ||
        (baishun && isBaishunLandscape(game));
    final rawPct = game?['webview_height_percent'];
    final fallback = tulasi
        ? 55.0
        : baishun
        ? 95.0
        : 70.0;
    final pct =
        (rawPct is num
                ? rawPct.toDouble()
                : double.tryParse(rawPct?.toString() ?? '') ?? fallback)
            .clamp(35.0, 95.0);
    final launchUri = Uri.tryParse(url);
    final roomId = widget.room['id']?.toString() ?? kBaishunShowroomRoomId;
    if (baishun) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => H5GameWebViewSheet(
          url: url,
          baishun: true,
          landscape: landscape,
          heightPercent: pct,
          roomId: roomId,
          gameMode: '3',
          supportZoom: false,
        ),
      );
      return;
    }
    InAppWebViewController? baishunController;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * (pct / 100.0),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(url)),
                initialUserScripts: () {
                  final scripts = <UserScript>[];
                  if (tulasi && !landscape) {
                    scripts.add(
                      UserScript(
                        source: tulasiPortraitOrientationSpoofJs,
                        injectionTime:
                            UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                    );
                  }
                  if (baishun) {
                    scripts.add(
                      UserScript(
                        source: baishunNativeBridgeBootstrapJs,
                        injectionTime:
                            UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                    );
                  }
                  if (scripts.isEmpty) return null;
                  return UnmodifiableListView<UserScript>(scripts);
                }(),
                initialSettings: InAppWebViewSettings(
                  transparentBackground: true,
                  supportZoom: false,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  javaScriptEnabled: true,
                  useHybridComposition: true,
                  domStorageEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  mixedContentMode: baishun
                      ? MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW
                      : MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                  useWideViewPort: tulasi || baishun,
                  loadWithOverviewMode: tulasi || baishun,
                  allowUniversalAccessFromFileURLs: baishun,
                  allowFileAccessFromFileURLs: baishun,
                ),
                shouldOverrideUrlLoading: (controller, action) async {
                  final navUrl = action.request.url?.toString() ?? '';
                  final proto = tulasiProtocolFromUrl(navUrl);
                  if (proto == TulasiWebProtocol.exit) {
                    Navigator.pop(context);
                    return NavigationActionPolicy.CANCEL;
                  }
                  if (proto == TulasiWebProtocol.recharge) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WalletScreen()),
                    );
                    return NavigationActionPolicy.CANCEL;
                  }
                  if (tulasi && launchUri != null) {
                    final patched = reattachTulasiLaunchQuery(
                      navUrl,
                      launchUri,
                    );
                    if (patched != null) {
                      await controller.loadUrl(
                        urlRequest: URLRequest(url: WebUri(patched)),
                      );
                      return NavigationActionPolicy.CANCEL;
                    }
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onWebViewCreated: (controller) {
                  baishunController = controller;
                  if (baishun) {
                    unawaited(
                      wireBaishunWebView(
                        controller: controller,
                        context: context,
                        roomId: roomId,
                        gameMode: '3',
                        onDestroy: () {
                          if (Navigator.canPop(context)) Navigator.pop(context);
                        },
                        onGameLoaded: () {},
                        onRecharge: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WalletScreen(),
                            ),
                          );
                          final userId = await baishunUserIdForWallet();
                          if (userId != null &&
                              userId.isNotEmpty &&
                              baishunController != null) {
                            await notifyBaishunWalletUpdate(
                              baishunController!,
                              userId: userId,
                            );
                          }
                        },
                      ),
                    );
                  }
                  final expectedHost = Uri.tryParse(url)?.host ?? '';
                  Future<bool> _originAllowed() async {
                    try {
                      final u = await controller.getUrl();
                      final host = u?.host ?? '';
                      if (host.isEmpty) return false;
                      if (expectedHost.isNotEmpty &&
                          (host == expectedHost ||
                              host.endsWith('.$expectedHost'))) {
                        return true;
                      }
                      const allow = <String>{
                        'sk-live-games.vercel.app',
                        'skliveparty.online',
                        'www.skliveparty.online',
                        'localhost',
                        'tulasigame.com',
                        'gamesp.tulasigame.com',
                      };
                      return allow.any(
                        (h) => host == h || host.endsWith('.$h'),
                      );
                    } catch (_) {
                      return false;
                    }
                  }

                  controller.addJavaScriptHandler(
                    handlerName: 'closeGame',
                    callback: (args) async {
                      if (!await _originAllowed()) return;
                      debugPrint('[WebView] closeGame called from web!');
                      Navigator.pop(context);
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'openWallet',
                    callback: (args) async {
                      if (!await _originAllowed()) return;
                      debugPrint('[WebView] openWallet called from web!');
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WalletScreen(),
                        ),
                      );
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'reportGameWin',
                    callback: (args) async {
                      if (!await _originAllowed()) {
                        debugPrint(
                          '[WebView] reportGameWin blocked: bad origin',
                        );
                        return;
                      }
                      if (args.isEmpty) return;
                      final gameSlug = args.isNotEmpty
                          ? args[0]?.toString()
                          : null;
                      final gameName = args.length > 1
                          ? args[1]?.toString()
                          : null;
                      final winCoins = args.length > 2
                          ? (args[2] is num
                                ? (args[2] as num).toInt()
                                : int.tryParse(args[2]?.toString() ?? '') ?? 0)
                          : 0;
                      final multiplier = args.length > 3
                          ? (args[3] is num
                                ? (args[3] as num).toDouble()
                                : double.tryParse(args[3]?.toString() ?? '') ??
                                      1)
                          : 1;
                      final betAmount = args.length > 4
                          ? (args[4] is num
                                ? (args[4] as num).toInt()
                                : int.tryParse(args[4]?.toString() ?? '') ?? 0)
                          : 0;

                      if (winCoins <= 0) return;

                      final profile = ref.read(userProfileProvider).value;
                      final username =
                          profile?['username']?.toString() ?? 'User';
                      final avatarUrl = profile?['avatar_url']?.toString();
                      final userId =
                          profile?['id']?.toString() ??
                          Supabase.instance.client.auth.currentUser?.id;

                      if (userId != null) {
                        unawaited(() async {
                          try {
                            await Future<void>.delayed(
                              const Duration(milliseconds: 650),
                            );
                            await Supabase.instance.client
                                .from('users')
                                .select('coins')
                                .eq('id', userId)
                                .maybeSingle();
                            ref.invalidate(userProfileProvider);
                          } catch (e) {
                            debugPrint('[WebView] balance refresh: $e');
                            ref.invalidate(userProfileProvider);
                          }
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '+${NumberFormatter.format(winCoins)} coins added',
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          );
                        }());
                      }

                      final multInt = multiplier
                          .round()
                          .clamp(1, 999999)
                          .toInt();
                      final tier = multInt >= 450
                          ? 'x500'
                          : multInt >= 225
                          ? 'x250'
                          : 'x$multInt';
                      final eventId = RoomLiveBroadcast.newEventId();
                      final source =
                          (gameName != null && gameName.trim().isNotEmpty)
                          ? gameName.trim()
                          : 'Game';

                      if (AppConstants.enableGlobalWinSvgaBroadcast) {
                        final announcement = GlobalWinAnnouncement(
                          id: eventId,
                          userId: userId,
                          username: username,
                          avatarUrl: avatarUrl,
                          sourceLabel: source,
                          rewardCoins: winCoins,
                          bonusMultiplier: multInt,
                          multiplierTier: tier,
                          variant: 'game',
                          roomId: widget.room['id']?.toString(),
                          createdAt: DateTime.now().toUtc(),
                        );
                        ref
                            .read(globalWinBroadcastControllerProvider.notifier)
                            .enqueueWin(announcement, dedupeKey: eventId);
                        if (AppConstants.useRealtimeGateway) {
                          unawaited(
                            RoomRealtimeSocket.instance.winNotify({
                              'id': eventId,
                              'event_id': eventId,
                              'user_id': userId,
                              'username': username,
                              'avatar_url': avatarUrl,
                              'source_label': source,
                              'reward_coins': winCoins,
                              'bonus_multiplier': multInt,
                              'multiplier_tier': tier,
                              'variant': 'game',
                              'room_id': widget.room['id']?.toString(),
                            }),
                          );
                        }
                      }

                      try {
                        await Supabase.instance.client.rpc(
                          'broadcast_room_win',
                          params: {
                            'p_room_id': widget.room['id'],
                            'p_game_slug': gameSlug ?? 'game',
                            'p_game_name': gameName ?? 'Game',
                            'p_win_coins': winCoins,
                            'p_multiplier': multiplier,
                            'p_bet_amount': betAmount,
                          },
                        );
                      } catch (e) {
                        debugPrint('[WebView] reportGameWin error: $e');
                      }
                    },
                  );
                },
                onLoadStart: (controller, url) {
                  debugPrint('[WebView] Loading: $url');
                },
                onLoadStop: (controller, url) async {
                  debugPrint('[WebView] Loaded: $url');
                  if (tulasi) {
                    if (launchUri != null) {
                      final patched = reattachTulasiLaunchQuery(
                        url?.toString() ?? '',
                        launchUri,
                      );
                      if (patched != null) {
                        await controller.loadUrl(
                          urlRequest: URLRequest(url: WebUri(patched)),
                        );
                        return;
                      }
                    }
                    if (!landscape) {
                      await controller.evaluateJavascript(
                        source: tulasiPinGameContentTopJs,
                      );
                      Future<void>.delayed(
                        const Duration(milliseconds: 400),
                        () {
                          controller.evaluateJavascript(
                            source: tulasiPinGameContentTopJs,
                          );
                        },
                      );
                    }
                    return;
                  }
                  if (baishun) return;
                  final accessToken =
                      Supabase.instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null || accessToken.isEmpty) return;
                  final host = url?.host ?? '';
                  const allow = <String>{
                    'sk-live-games.vercel.app',
                    'skliveparty.online',
                    'www.skliveparty.online',
                    'localhost',
                  };
                  final ok = allow.any(
                    (h) => host == h || host.endsWith('.$h'),
                  );
                  if (!ok) return;
                  final payload = jsonEncode({
                    'access_token': accessToken,
                    'gateway': AppConstants.realtimeGatewayUrl,
                  });
                  try {
                    await controller.evaluateJavascript(
                      source:
                          '''
                        (function(){
                          try {
                            window.__SK_SESSION = $payload;
                            window.dispatchEvent(new CustomEvent('sklive-auth', { detail: window.__SK_SESSION }));
                          } catch (e) {}
                        })();
                      ''',
                    );
                  } catch (e) {
                    debugPrint('[WebView] session inject failed: $e');
                  }
                },
                onReceivedError: (controller, request, error) {
                  debugPrint('[WebView] Error: ${error.description}');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceWaveIndicator extends StatefulWidget {
  const VoiceWaveIndicator({super.key});

  @override
  State<VoiceWaveIndicator> createState() => _VoiceWaveIndicatorState();
}

class _VoiceWaveIndicatorState extends State<VoiceWaveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            _buildWave(
              1.0 + (_controller.value * 0.4),
              0.6 - (_controller.value * 0.6),
            ),
            _buildWave(
              1.2 + (_controller.value * 0.5),
              0.3 - (_controller.value * 0.3),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWave(double scale, double opacity) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Container(
      width: 46 * scale,
      height: 46 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.yellowAccent.withValues(alpha: opacity),
          width: 2,
        ),
      ),
    );
  }
}

class _SeatCpLineSvga extends StatelessWidget {
  static const asset = 'assets/room/effects/beaver_cp_line.svga';

  const _SeatCpLineSvga();

  @override
  Widget build(BuildContext context) {
    return RaveSVGAPlayer(resUrl: asset, repeat: true, fit: BoxFit.contain);
  }
}

class _AnnouncementMarquee extends StatefulWidget {
  const _AnnouncementMarquee({required this.text});

  final String text;

  @override
  State<_AnnouncementMarquee> createState() => _AnnouncementMarqueeState();
}

class _AnnouncementMarqueeState extends State<_AnnouncementMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0;
  double _viewportWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
  }

  @override
  void didUpdateWidget(covariant _AnnouncementMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle get _style => const TextStyle(
    color: Colors.amber,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  void _measureAndStart() {
    if (!mounted) return;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: _style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    _textWidth = painter.width;
    _viewportWidth = context.size?.width ?? 0;
    if (_viewportWidth <= 0) return;

    final needsScroll = _textWidth > _viewportWidth - 4;
    if (!needsScroll) {
      _controller.stop();
      _controller.value = 0;
      setState(() {});
      return;
    }

    final travel = _textWidth + 36;
    final seconds = (travel / 28).clamp(6.0, 18.0);
    _controller
      ..duration = Duration(milliseconds: (seconds * 1000).round())
      ..repeat();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if ((_viewportWidth - constraints.maxWidth).abs() > 0.5) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _viewportWidth = constraints.maxWidth;
              _measureAndStart();
            });
          }

          final needsScroll = _textWidth > constraints.maxWidth - 4;
          if (!needsScroll) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style,
              ),
            );
          }

          final gap = 36.0;
          return ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final dx = -(_controller.value * (_textWidth + gap));
                return Stack(
                  children: [
                    Transform.translate(
                      offset: Offset(dx, 0),
                      child: Text(widget.text, maxLines: 1, style: _style),
                    ),
                    Transform.translate(
                      offset: Offset(dx + _textWidth + gap, 0),
                      child: Text(widget.text, maxLines: 1, style: _style),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RoomMicLayout {
  const _RoomMicLayout({
    required this.id,
    required this.micCount,
    required this.rows,
    required this.title,
    required this.subtitle,
    this.ownerSeatIndex,
  });

  final String id;
  final int micCount;
  final List<int> rows;
  final String title;
  final String subtitle;
  final int? ownerSeatIndex;

  int get maxColumns => rows.fold<int>(0, (m, n) => n > m ? n : m);
}

class _SeatSoundWaves extends StatelessWidget {
  static const _softAsset = 'assets/room/effects/beaver_baiyinbo.svga';
  static const _loudAsset = 'assets/room/effects/beaver_hongyinbo.svga';

  static const loudThreshold = 28.0;

  final bool isActive;
  final double soundLevel;
  final double size;
  final bool forceLoud;
  final bool micOpen;

  const _SeatSoundWaves({
    required this.isActive,
    this.soundLevel = 0,
    this.size = _kSeatSoundWave,
    this.forceLoud = false,
    this.micOpen = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();

    final isLoud = forceLoud || soundLevel >= loudThreshold;

    final showSoft = micOpen && (forceLoud || !isLoud);
    if (!showSoft && !isLoud) return const SizedBox.shrink();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          if (showSoft)
            const RaveSVGAPlayer(
              key: ValueKey('seat_soft_svga'),
              resUrl: _softAsset,
              repeat: true,
              fit: BoxFit.contain,
            ),
          if (isLoud)
            const RaveSVGAPlayer(
              key: ValueKey('seat_loud_svga'),
              resUrl: _loudAsset,
              repeat: true,
              fit: BoxFit.contain,
            ),
        ],
      ),
    );
  }
}
