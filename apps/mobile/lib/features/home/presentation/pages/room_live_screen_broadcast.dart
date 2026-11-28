import 'package:sk_live/core/util/dev_log.dart';
part of 'room_live_screen.dart';

mixin _RoomLiveBroadcastMixin on ConsumerState<RoomLiveScreen> {
  _RoomLiveScreenState get _rb => this as _RoomLiveScreenState;

  void _setupRoomBroadcastListeners() {
    for (final event in RoomLiveBroadcast.events) {
      _rb._roomChannel.onBroadcast(
        event: event,
        callback: (raw) {
          if (!mounted) return;
          final payload = RoomLiveBroadcast.unwrapPayload(
            Map<String, dynamic>.from(raw),
          );
          switch (event) {
            case RoomLiveBroadcast.chat:
              _handleRoomChatBroadcast(payload);
            case RoomLiveBroadcast.gift:
              _handleRoomGiftBroadcast(payload);
            case RoomLiveBroadcast.seat:
              _applySeatBroadcast(payload);
            case RoomLiveBroadcast.kick:
              _handleRoomKickBroadcast(payload);
            case RoomLiveBroadcast.meta:
              _handleRoomMetaBroadcast(payload);
            case RoomLiveBroadcast.micEmoji:
              _handleRoomMicEmojiBroadcast(payload);
            case RoomLiveBroadcast.entrance:
              _handleRoomEntranceBroadcast(payload);
            case RoomLiveBroadcast.luckyWin:
              _handleRoomLuckyWinBroadcast(payload);
          }
        },
      );
    }

    _rb._roomChannel.onPostgresChanges(
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
  }

  bool _markBroadcastSeen(dynamic eventId) {
    return RoomLiveBroadcast.shouldIgnore(
      _rb._seenBroadcastEventIds,
      eventId?.toString(),
    );
  }

  Future<void> _sendRoomBroadcast(
    String event,
    Map<String, dynamic> fields, {
    bool priority = false,
    Map<String, dynamic>? zegoPayload,
  }) async {
    final myUser = ref.read(userProfileProvider).value;
    final eventId =
        fields['event_id']?.toString() ?? RoomLiveBroadcast.newEventId();
    _rb._seenBroadcastEventIds.add(eventId);
    while (_rb._seenBroadcastEventIds.length >
        _RoomLiveScreenState._maxSeenBroadcastIds) {
      _rb._seenBroadcastEventIds.remove(_rb._seenBroadcastEventIds.first);
    }

    final payload = RoomLiveBroadcast.envelope(
      roomId: widget.room['id'].toString(),
      actorUserId: myUser?['id']?.toString() ?? '',
      eventId: eventId,
      fields: fields,
    );

    final zegoRoomId =
        _rb._zegoRoomId ?? widget.room['id'].toString().replaceAll('-', '');

    await RoomZegoSyncService.broadcastPrimary(
      zegoRoomId: zegoRoomId,
      event: event,
      payload: payload,
      backupChannel: _rb._roomChannel,
      zegoPayload: zegoPayload,
      priority:
          priority ||
          event == RoomLiveBroadcast.gift ||
          event == RoomLiveBroadcast.luckyWin,
    );

    if (event == RoomLiveBroadcast.seat) {
      _rb._lastSeatBroadcastAt = DateTime.now();
    }
  }

  void _scheduleSeatReconcile() {
    _rb._seatReconcileTimer?.cancel();
    _rb._seatReconcileTimer = Timer(
      _RoomLiveScreenState._seatReconcileDebounce,
      () {
        if (!mounted || _rb._isLeavingRoom) return;
        _rb._fetchSeats(refreshGiftTotals: false);
      },
    );
  }

  void _startReconcilePoll() {
    _rb._reconcilePollTimer?.cancel();
    _rb._reconcilePollTimer = Timer.periodic(
      _RoomLiveScreenState._reconcilePollInterval,
      (_) {
        if (!mounted || _rb._isLeavingRoom) return;
        unawaited(_rb._fetchSeats(refreshGiftTotals: false, force: true));
        unawaited(_rb._fetchMessages());
      },
    );
  }

  void _stopReconcilePoll() {
    _rb._reconcilePollTimer?.cancel();
    _rb._reconcilePollTimer = null;
    _rb._seatReconcileTimer?.cancel();
    _rb._seatReconcileTimer = null;
  }

  void _applySeatBroadcast(Map<String, dynamic> payload) {
    if (_markBroadcastSeen(payload['event_id'])) return;

    final action = payload['action']?.toString() ?? '';
    final rawIndex = payload['seat_index'] ?? payload['seatIndex'];
    final seatIndex = rawIndex is num
        ? rawIndex.toInt()
        : int.tryParse(rawIndex?.toString() ?? '');
    final myId = Supabase.instance.client.auth.currentUser?.id;

    if (action == 'leave' || action == 'force_leave') {
      final leavingId =
          payload['user_id']?.toString() ??
          payload['actor_user_id']?.toString();
      final indexUsable =
          seatIndex != null && seatIndex >= 0 && seatIndex < _rb._seats.length;
      if (!indexUsable && leavingId != null && leavingId.isNotEmpty) {
        devLog('[SEAT] broadcast leave without index — clear user=$leavingId');
        _rb._lastSeatBroadcastAt = DateTime.now();
        RoomSeatSyncService.markVacated(
          _rb._recentlyVacatedSeatUsers,
          leavingId,
        );
        if (mounted) {
          setState(() {
            for (var i = 0; i < _rb._seats.length; i++) {
              if (_rb._seats[i]['user_id']?.toString() == leavingId) {
                _rb._seats[i] = {
                  ...Map<String, dynamic>.from(_rb._seats[i]),
                  'user_id': null,
                  'user': null,
                  'is_muted': false,
                };
              }
            }
            if (leavingId == myId) _rb._mySeatIndex = null;
            _rb._updateAudienceList();
          });
        }
        if (leavingId == myId) {
          unawaited(_rb._stopLocalPublishTracked());
        }
        return;
      }
    }

    if (seatIndex == null || seatIndex < 0 || seatIndex >= _rb._seats.length) {
      devLog(
        '[SEAT] broadcast ignored bad index action=$action '
        'seatIndex=$seatIndex raw=$rawIndex',
      );
      return;
    }

    final mutedFlag = payload.containsKey('is_muted')
        ? payload['is_muted'] == true
        : payload['isMuted'] == true;
    _rb._lastSeatBroadcastAt = DateTime.now();
    devLog(
      '[SEAT] broadcast apply action=$action seat=$seatIndex '
      'user=${payload['user_id']} muted=$mutedFlag '
      'mySeat=${_rb._mySeatIndex}',
    );

    setState(() {
      switch (action) {
        case 'sit':
        case 'take':
          final user = payload['user'];
          final sitUserId = payload['user_id']?.toString();
          RoomSeatSyncService.clearVacated(
            _rb._recentlyVacatedSeatUsers,
            sitUserId,
          );
          if (sitUserId != null) {
            for (var i = 0; i < _rb._seats.length; i++) {
              if (i != seatIndex &&
                  _rb._seats[i]['user_id']?.toString() == sitUserId) {
                _rb._seats[i] = {
                  ...Map<String, dynamic>.from(_rb._seats[i]),
                  'user_id': null,
                  'user': null,
                  'is_muted': false,
                };
              }
            }
          }
          _rb._seats[seatIndex] = {
            ...Map<String, dynamic>.from(_rb._seats[seatIndex]),
            'user_id': payload['user_id'],
            'user': user is Map ? Map<String, dynamic>.from(user) : user,
            'is_muted': mutedFlag,
            'is_locked': false,
          };
          if (sitUserId == myId) {
            _rb._mySeatIndex = seatIndex;
            _rb._isMuted = mutedFlag;
            devLog('[SEAT] broadcast SELF sit → mySeat=$seatIndex');
          }
        case 'leave':
          final leavingId =
              payload['user_id']?.toString() ??
              _rb._seats[seatIndex]['user_id']?.toString();
          RoomSeatSyncService.markVacated(
            _rb._recentlyVacatedSeatUsers,
            leavingId,
          );
          if (_rb._seats[seatIndex]['user_id']?.toString() == myId ||
              leavingId == myId) {
            devLog(
              '[SEAT] broadcast SELF leave seat=$seatIndex '
              'leavingId=$leavingId → mySeat=null',
            );
            _rb._mySeatIndex = null;
          }
          _rb._seats[seatIndex] = {
            ...Map<String, dynamic>.from(_rb._seats[seatIndex]),
            'user_id': null,
            'user': null,
            'is_muted': false,
          };
        case 'mute':
        case 'admin_mute':
          final isMe =
              _rb._seats[seatIndex]['user_id']?.toString() == myId ||
              payload['user_id']?.toString() == myId;
          if (isMe) {
            if (!mutedFlag &&
                _rb._localMuteGuardUntil != null &&
                DateTime.now().isBefore(_rb._localMuteGuardUntil!)) {
              debugPrint('[SEAT] IN unmute UI ignored — local mute guard');
              break;
            }
            if (mutedFlag &&
                _rb._localUnmuteGuardUntil != null &&
                DateTime.now().isBefore(_rb._localUnmuteGuardUntil!)) {
              debugPrint('[SEAT] IN mute UI ignored — local unmute guard');
              break;
            }
          }
          _rb._seats[seatIndex]['is_muted'] = mutedFlag;
          if (isMe) {
            _rb._isMuted = mutedFlag;
            if (mutedFlag) {
              _rb._localUnmuteGuardUntil = null;
              _rb._localMuteGuardUntil = DateTime.now().add(
                const Duration(seconds: 8),
              );
            } else {
              _rb._localMuteGuardUntil = null;
              _rb._localUnmuteGuardUntil = DateTime.now().add(
                const Duration(seconds: 8),
              );
            }
          }
        case 'lock':
          _rb._seats[seatIndex]['is_locked'] =
              payload['is_locked'] == true || payload['isLocked'] == true;
      }
      _rb._updateAudienceList();
    });

    if (action == 'leave') {
      final leavingId = payload['user_id']?.toString();
      if (leavingId != null && leavingId == myId) {
        unawaited(_rb._stopLocalPublishTracked());
      }
    }

    if ((action == 'mute' || action == 'admin_mute') &&
        payload['user_id']?.toString() == myId) {
      final muted = mutedFlag;
      if (!muted &&
          _rb._localMuteGuardUntil != null &&
          DateTime.now().isBefore(_rb._localMuteGuardUntil!)) {
        debugPrint('[SEAT] IN unmute ignored — local mute guard');
        return;
      }
      if (muted &&
          _rb._localUnmuteGuardUntil != null &&
          DateTime.now().isBefore(_rb._localUnmuteGuardUntil!)) {
        debugPrint('[SEAT] IN mute ignored — local unmute guard');
        return;
      }
      unawaited(() async {
        try {
          if (!muted) {
            await _rb._startSpeaking(true);
          } else {
            await _rb._stopLocalPublishTracked();
          }
        } catch (e) {
          debugPrint('Seat mute Zego apply failed: $e');
        }
      }());
    }

    if (action == 'sit' || action == 'take' || action == 'leave') {
      unawaited(_rb._refreshSeatCpPartners());
    }
  }

  Future<bool> _broadcastSeatAction({
    required String action,
    required int seatIndex,
    String? userId,
    Map<String, dynamic>? user,
    bool? isMuted,
    bool? isLocked,
  }) async {
    if (AppConstants.useRealtimeGateway) {
      final roomId = widget.room['id'].toString();
      final eventId = RoomLiveBroadcast.newEventId();
      _rb._seenBroadcastEventIds.add(eventId);
      final socket = RoomRealtimeSocket.instance;
      final body = <String, dynamic>{
        'roomId': roomId,
        'seatIndex': seatIndex,
        'seat_index': seatIndex,
        if (user != null) 'user': user,
        if (userId != null) 'user_id': userId,
        'event_id': eventId,
        if (isMuted != null) 'isMuted': isMuted,
        if (isMuted != null) 'is_muted': isMuted,
        'isLocked': isLocked ?? action == 'lock',
        'is_locked': isLocked ?? action == 'lock',
      };
      Map<String, dynamic>? res;
      switch (action) {
        case 'sit':
        case 'take':
          res = await socket.seatClaim(body);
          break;
        case 'leave':
          res = await socket.seatLeave(body);
          break;
        case 'mute':
        case 'admin_mute':
          res = await socket.seatMute(body);
          break;
        case 'lock':
        case 'unlock':
          res = await socket.seatLock(body);
          break;
        default:
          res = await socket.publish(
            roomId: roomId,
            event: RoomLiveBroadcast.eventSeat,
            data: {
              'action': action,
              'seat_index': seatIndex,
              if (userId != null) 'user_id': userId,
              if (user != null) 'user': user,
              if (isMuted != null) 'is_muted': isMuted,
              if (isLocked != null) 'is_locked': isLocked,
              'event_id': eventId,
            },
          );
      }
      _rb._lastSeatBroadcastAt = DateTime.now();
      if (res?['ok'] != true) {
        devLog(
          '[SEAT] gateway ack FAIL action=$action seat=$seatIndex res=$res',
        );
        return false;
      }
      devLog('[SEAT] gateway ack OK action=$action seat=$seatIndex res=$res');
      if ((action == 'sit' || action == 'take') && mounted) {
        final seatsRaw = res?['seats'];
        final seatRaw = res?['seat'];
        if (seatsRaw is List || seatRaw is Map) {
          final snap = <String, dynamic>{
            if (seatsRaw is List)
              'seats': seatsRaw
            else if (seatRaw is Map)
              'seats': [Map<String, dynamic>.from(seatRaw)],
          };
          devLog('[SEAT] applying claim-ack seats immediately');
          _rb._applyGatewaySnapshot(snap);
        }
      }
      return true;
    }

    await _sendRoomBroadcast(RoomLiveBroadcast.seat, {
      'action': action,
      'seat_index': seatIndex,
      if (userId != null) 'user_id': userId,
      if (user != null) 'user': user,
      if (isMuted != null) 'is_muted': isMuted,
      if (isLocked != null) 'is_locked': isLocked,
    });
    return true;
  }

  void _handleRoomChatBroadcast(Map<String, dynamic> payload) {
    final eventRoomId = payload['room_id']?.toString() ?? '';
    final currentRoomId = widget.room['id']?.toString() ?? '';
    if (eventRoomId.isNotEmpty &&
        currentRoomId.isNotEmpty &&
        eventRoomId != currentRoomId) {
      return;
    }

    if (_markBroadcastSeen(payload['event_id'])) return;

    final msgClearedAtStr = _rb._roomData?['chat_cleared_at']?.toString();
    if (msgClearedAtStr != null) {
      final clearedTime = DateTime.tryParse(msgClearedAtStr);
      final msgTime = DateTime.tryParse(payload['sent_at']?.toString() ?? '');
      if (clearedTime != null &&
          msgTime != null &&
          msgTime.isBefore(clearedTime)) {
        return;
      }
    }

    final type = payload['type']?.toString() ?? 'chat';
    final message = {
      'id': payload['message_id'] ?? payload['event_id'],
      'user_id': payload['user_id'],
      'content': payload['content'],
      'type': type,
      'created_at': payload['sent_at'] ?? DateTime.now().toIso8601String(),
      if (payload['user'] != null) 'user': payload['user'],
      if (payload['metadata'] != null) 'metadata': payload['metadata'],
    };

    if (mounted) {
      _rb._tryAppendChatMessage(message);
    }
  }

  Future<void> _broadcastChat({
    required String eventId,
    required String type,
    required String content,
    String? userId,
    Map<String, dynamic>? user,
    Map<String, dynamic>? metadata,
    String? messageId,
  }) async {
    if (AppConstants.useRealtimeGateway) {
      Map<String, dynamic>? slimUser;
      if (user != null) {
        slimUser = {
          'id': user['id'],
          'username': user['username'],
          'avatar_url': user['avatar_url'],
          'vip_level': user['vip_level'],
        };
      }
      try {
        await RoomRealtimeSocket.instance.chatSend({
          'roomId': widget.room['id'].toString(),
          'content': content,
          'event_id': eventId,
          'type': type,
          if (slimUser != null) 'user': slimUser,
          if (userId != null) 'user_id': userId,
          if (metadata != null) 'metadata': metadata,
          if (messageId != null) 'message_id': messageId,
        });
      } catch (e) {
        debugPrint('[Gateway] chatSend failed: $e');
      }
      return;
    }

    await _sendRoomBroadcast(RoomLiveBroadcast.chat, {
      'event_id': eventId,
      'type': type,
      'content': content,
      if (userId != null) 'user_id': userId,
      if (user != null) 'user': user,
      if (metadata != null) 'metadata': metadata,
      if (messageId != null) 'message_id': messageId,
    });
  }

  void _handleRoomGiftBroadcast(Map<String, dynamic> payload) {
    if (_markBroadcastSeen(payload['event_id'])) return;

    final totals = payload['seat_gift_totals'];
    if (totals is Map) {
      _applySeatGiftTotals(totals);
    } else {
      _applySeatGiftDelta(payload['seat_gift_delta']);
    }

    final giftMessages = _rb._giftMessagesFromPayload(payload);
    Map<String, dynamic>? msg = giftMessages.isNotEmpty
        ? giftMessages.first
        : null;
    if (mounted) _rb._appendGiftChatMessages(giftMessages);
    for (final m in giftMessages) {
      if (m['type'] == 'gift') {
        _rb._maybeShowLuckyWinFromGiftMessage(m);
      }
    }

    final batchId =
        payload['animation_batch_id']?.toString() ??
        payload['event_id']?.toString() ??
        '';
    final animationFields = _rb._giftAnimationFieldsFromPayload(
      payload,
      giftMessages,
    );

    _rb._maybeShowFullScreenGiftAnimation(
      batchId: batchId,
      svgaUrl: animationFields.svgaUrl,
      isFullScreen: animationFields.isFullScreen,
    );

    if (animationFields.targetIds.isNotEmpty) {
      _rb._enqueueGiftAnimation(
        dedupeKey: batchId.isNotEmpty
            ? batchId
            : 'gift_${payload['sender_id']}_${animationFields.targetIds.join('_')}',
        senderId:
            payload['sender_id']?.toString() ??
            payload['actor_user_id']?.toString() ??
            '',
        targetIds: animationFields.targetIds,
        giftIcon: animationFields.giftIcon,
        quantity: animationFields.quantity,
        isFullScreen: animationFields.isFullScreen,
        svgaUrl: animationFields.svgaUrl,
        playFullScreenSvga: false,
      );
      if (msg != null) {
        _rb._maybeEnqueueBigGiftPattiFromGiftMessage(msg);
      }
    } else if (msg != null && msg['type'] == 'gift') {
      _rb._triggerGiftAnimation(msg);
    }
  }

  Future<void> _broadcastRoomGift(Map<String, dynamic> payload) async {
    if (payload['settled_on_gateway'] == true) {
      debugPrint('[GiftAnim] skip giftNotify — settled_on_gateway');
      return;
    }
    if (AppConstants.useRealtimeGateway) {
      try {
        await RoomRealtimeSocket.instance.giftNotify({
          'roomId': widget.room['id'].toString(),
          ...payload,
        });
      } catch (e) {
        debugPrint('[Gateway] giftNotify failed: $e');
      }
      return;
    }
    await _sendRoomBroadcast(RoomLiveBroadcast.gift, payload);
  }

  void _applySeatGiftDelta(dynamic delta) {
    if (delta is! Map) return;
    var changed = false;
    delta.forEach((key, value) {
      final receiverId = key.toString();
      final amount = (value as num?)?.toInt() ?? 0;
      if (amount <= 0) return;
      _rb._seatGiftTotals[receiverId] =
          (_rb._seatGiftTotals[receiverId] ?? 0) + amount;
      changed = true;
    });
    if (changed) _rb._scheduleSeatGiftRebuild();
  }

  void _applySeatGiftTotals(Map totals) {
    var changed = false;
    totals.forEach((key, value) {
      final receiverId = key.toString();
      final amount = (value as num?)?.toInt() ?? 0;
      if (amount < 0) return;
      if (_rb._seatGiftTotals[receiverId] == amount) return;
      _rb._seatGiftTotals[receiverId] = amount;
      changed = true;
    });
    if (changed) _rb._scheduleSeatGiftRebuild();
  }

  void _handleRoomKickBroadcast(Map<String, dynamic> payload) {
    if (_markBroadcastSeen(payload['event_id'])) return;

    final targetId = payload['user_id']?.toString();
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (targetId != null && targetId == myId) {
      _rb._handleKickedFromRoom(payload['reason']?.toString());
    }
  }

  Future<void> _broadcastRoomKick({
    required String userId,
    String? reason,
  }) async {
    await _sendRoomBroadcast(RoomLiveBroadcast.kick, {
      'user_id': userId,
      if (reason != null) 'reason': reason,
    });
  }

  void _handleRoomMetaBroadcast(Map<String, dynamic> payload) {
    if (_markBroadcastSeen(payload['event_id'])) return;
    if (_rb._roomData == null) return;

    final prevMicCount = _rb._roomData!['mic_count'];
    final nextMicCount = payload.containsKey('mic_count')
        ? payload['mic_count']
        : null;

    setState(() {
      if (payload.containsKey('mic_count')) {
        _rb._roomData!['mic_count'] = payload['mic_count'];
      }
      if (payload.containsKey('party_mode')) {
        _rb._roomData!['party_mode'] = payload['party_mode'];
      }
      if (payload.containsKey('admin_only_chat')) {
        _rb._roomData!['admin_only_chat'] = payload['admin_only_chat'];
      }
      if (payload.containsKey('chat_cleared_at')) {
        _rb._roomData!['chat_cleared_at'] = payload['chat_cleared_at'];
        _rb._messages.clear();
      }
    });
    if (payload.containsKey('chat_cleared_at')) {
      _rb._notifyChatListChanged();
    }
    if (nextMicCount != null) {
      if (nextMicCount != prevMicCount) {
        _rb._initSeats(source: 'room_meta_broadcast');
      } else {
        devLog(
          '[SEAT] room_meta mic_count unchanged ($nextMicCount) — skip initSeats',
        );
      }
    }
    if (payload['chat_cleared_at'] != null) {
      _rb._fetchMessages();
    }
  }

  Future<void> _broadcastRoomMeta(Map<String, dynamic> fields) async {
    await _sendRoomBroadcast(RoomLiveBroadcast.meta, fields);
  }

  void _handleRoomMicEmojiBroadcast(Map<String, dynamic> payload) {
    if (_markBroadcastSeen(payload['event_id'])) return;

    final seatIndex = (payload['seat_index'] as num?)?.toInt();
    if (seatIndex == null) return;

    _rb._playMicEmojiOverlay(
      seatIndex: seatIndex,
      imageUrl: payload['image_url']?.toString() ?? '',
      svgaUrl: payload['svga_url']?.toString(),
      dedupeKey: payload['event_id']?.toString(),
    );
  }

  Future<void> _broadcastMicEmoji({
    required int seatIndex,
    required String imageUrl,
    String? svgaUrl,
    String? emojiId,
    String? eventId,
  }) async {
    await _sendRoomBroadcast(RoomLiveBroadcast.micEmoji, {
      if (eventId != null) 'event_id': eventId,
      'seat_index': seatIndex,
      'image_url': imageUrl,
      if (svgaUrl != null && svgaUrl.isNotEmpty) 'svga_url': svgaUrl,
      if (emojiId != null) 'emoji_id': emojiId,
    });
  }

  void _handleRoomEntranceBroadcast(Map<String, dynamic> payload) {
    if (_markBroadcastSeen(payload['event_id'])) {
      debugPrint(
        '[Entrance] recv skip duplicate event_id=${payload['event_id']}',
      );
      return;
    }

    final userId = _rb._normalizePresenceUserId(payload['user_id']);
    if (userId == null) {
      debugPrint('[Entrance] recv skip: missing user_id');
      return;
    }

    final selfId = _rb._normalizePresenceUserId(
      ref.read(userProfileProvider).value?['id'],
    );
    if (selfId != null && userId == selfId) {
      debugPrint('[Entrance] recv skip self uid=$userId');
      return;
    }

    debugPrint(
      '[Entrance] recv broadcast uid=$userId '
      'user=${payload['username']} '
      'car=${payload['car_svga'] != null} '
      'patti=${payload['patti_svga'] != null}',
    );

    unawaited(
      _showEntranceFromBroadcast(
        userId: userId,
        username: payload['username']?.toString() ?? 'User',
        userProfile: payload['user_profile'] is Map
            ? Map<String, dynamic>.from(payload['user_profile'] as Map)
            : null,
        carSvga: payload['car_svga']?.toString(),
        pattiSvga: payload['patti_svga']?.toString(),
        pattiUrl: payload['patti_url']?.toString(),
        fromDedicatedBroadcast: true,
      ),
    );
  }

  Future<void> _showEntranceFromBroadcast({
    required String userId,
    required String username,
    Map<String, dynamic>? userProfile,
    String? carSvga,
    String? pattiSvga,
    String? pattiUrl,
    bool fromDedicatedBroadcast = false,
  }) async {
    final uid = _rb._normalizePresenceUserId(userId);
    if (uid == null) return;

    if (_rb._entranceInFlight.contains(uid)) {
      debugPrint('[Entrance] show skip inFlight uid=$uid');
      return;
    }

    if (_rb._entranceHandledUserIds.contains(uid)) {
      _rb._pruneEntranceLastShownAt();
      final last = _rb._entranceLastShownAt[uid];
      final withinEcho =
          last != null &&
          DateTime.now().difference(last) <
              _RoomLiveScreenState._entranceEchoCooldown;
      if (!fromDedicatedBroadcast || withinEcho) {
        debugPrint(
          '[Entrance] show skip handled uid=$uid '
          'dedicated=$fromDedicatedBroadcast echo=$withinEcho',
        );
        return;
      }
      debugPrint('[Entrance] rejoin broadcast — clear handled uid=$uid');
      _rb._entranceHandledUserIds.remove(uid);
    }

    _rb._entranceInFlight.add(uid);
    _rb._entranceHandledUserIds.add(uid);

    try {
      if (carSvga == null && pattiSvga == null && pattiUrl == null) {
        debugPrint('[Entrance] show skip no assets uid=$uid');
        return;
      }

      final profile =
          userProfile ??
          await Supabase.instance.client
              .from('users')
              .select(
                'id, username, avatar_url, vip_level, wealth_level, user_level',
              )
              .eq('id', uid)
              .maybeSingle();

      if (!mounted || profile == null) {
        debugPrint('[Entrance] show skip profile null uid=$uid');
        return;
      }

      await _rb._armEntranceAnimation(
        userProfile: Map<String, dynamic>.from(profile),
        carSvga: carSvga,
        pattiSvga: pattiSvga,
        pattiUrl: pattiUrl,
      );
    } finally {
      _rb._entranceInFlight.remove(uid);
    }
  }

  Future<void> _broadcastEntrance({
    required String userId,
    required String username,
    required Map<String, dynamic> userProfile,
    String? carSvga,
    String? pattiSvga,
    String? pattiUrl,
  }) async {
    debugPrint('[Entrance] publish broadcast uid=$userId user=$username');
    await _sendRoomBroadcast(RoomLiveBroadcast.entrance, {
      'user_id': userId,
      'username': username,
      'user_profile': userProfile,
      if (carSvga != null) 'car_svga': carSvga,
      if (pattiSvga != null) 'patti_svga': pattiSvga,
      if (pattiUrl != null) 'patti_url': pattiUrl,
    });
  }

  void _handleRoomLuckyWinBroadcast(Map<String, dynamic> payload) {
    if (_markBroadcastSeen(payload['event_id'])) return;

    final message = payload['message'];
    if (message is! Map) return;

    final msg = Map<String, dynamic>.from(message);
    msg['room_id'] ??= payload['room_id'] ?? widget.room['id'];
    // The roll stopped: post the gift's held comment with its multiplier.
    _rb._settleLuckyGiftComment(msg);
    if (mounted) {
      _rb._tryAppendChatMessage(msg);
    }
    _rb._maybeEnqueueLuckyWinFloats(msg);
    _rb._enqueueGlobalWinBanner(msg);
  }

  void _handleGatewayLuckyWinSocket(Map<String, dynamic> payload) {
    final giftLogId = payload['gift_log_id']?.toString();
    final eventId =
        payload['event_id']?.toString() ??
        (giftLogId != null && giftLogId.isNotEmpty
            ? 'lucky_win_$giftLogId'
            : null);
    if (giftLogId != null &&
        giftLogId.isNotEmpty &&
        _markBroadcastSeen('gift_log_lucky_$giftLogId')) {
      return;
    }

    final variant = payload['variant']?.toString() ?? 'lucky';
    final isPro = variant == 'lucky_pro';
    final bonusCoins =
        (payload['bonus_coins'] as num?)?.toInt() ??
        (payload['reward_coins'] as num?)?.toInt() ??
        0;
    if (bonusCoins <= 0) return;

    final batchId = payload['animation_batch_id']?.toString();
    final username =
        payload['sender_username']?.toString() ??
        payload['username']?.toString() ??
        'User';
    final avatarUrl =
        payload['sender_avatar']?.toString() ??
        payload['avatar_url']?.toString();
    final message = <String, dynamic>{
      'type': 'lucky_win',
      'id': 'lucky_${eventId ?? giftLogId ?? batchId}',
      'user_id': payload['user_id'],
      'room_id': payload['room_id'] ?? widget.room['id'],
      'created_at': payload['created_at'] ?? DateTime.now().toIso8601String(),
      'content': isPro
          ? 'You won $bonusCoins lucky pro bonus!'
          : 'You won $bonusCoins lucky bonus!',
      'user': {
        'id': payload['user_id'],
        'username': username,
        'avatar_url': avatarUrl,
      },
      'metadata': {
        'event_id': eventId,
        if (giftLogId != null && giftLogId.isNotEmpty) 'gift_log_id': giftLogId,
        if (batchId != null && batchId.isNotEmpty)
          'animation_batch_id': batchId,
        'lucky_engine': 'gateway',
        'lucky_bonus_won': !isPro,
        'lucky_pro_bonus_won': isPro,
        'lucky_bonus_coins': isPro ? 0 : bonusCoins,
        'lucky_pro_bonus_coins': isPro ? bonusCoins : 0,
        'bonus_multiplier': payload['bonus_multiplier'],
        'multiplier_tier': payload['multiplier_tier'],
        'gift_name': payload['gift_name'],
        'gift_icon': payload['gift_icon'],
        'gift_id': payload['gift_id'],
        'sender_id': payload['user_id'],
        'target_id': payload['receiver_id'],
        'sender_username': username,
        'sender_avatar': avatarUrl,
        'is_lucky_gift': !isPro,
        'is_lucky_pro_gift': isPro,
      },
    };

    _handleRoomLuckyWinBroadcast({
      'event_id': eventId,
      'room_id': payload['room_id'] ?? widget.room['id'],
      'message': message,
    });
  }

  Future<void> _broadcastLuckyWin(Map<String, dynamic> message) async {
    await _sendRoomBroadcast(RoomLiveBroadcast.luckyWin, {'message': message});
  }

  void _onRoomMessagePostgresReconcile(Map<String, dynamic> newMessage) {
    final metadata = newMessage['metadata'];
    String? eventId;
    if (metadata is Map) {
      eventId = metadata['event_id']?.toString();
    }
    final messageId = newMessage['id']?.toString();
    if (eventId != null && _rb._seenBroadcastEventIds.contains(eventId)) {
      return;
    }
    if (messageId != null && _rb._seenBroadcastEventIds.contains(messageId)) {
      return;
    }

    final batchId = metadata is Map
        ? metadata['animation_batch_id']?.toString()
        : null;
    if (batchId != null &&
        batchId.isNotEmpty &&
        _rb._seenBroadcastEventIds.contains('gift_$batchId')) {
      return;
    }

    final msgClearedAtStr = _rb._roomData?['chat_cleared_at']?.toString();
    if (msgClearedAtStr != null) {
      final clearedTime = DateTime.tryParse(msgClearedAtStr);
      final msgTimeStr = newMessage['created_at']?.toString() ?? '';
      final msgTime = DateTime.tryParse(msgTimeStr);
      if (clearedTime != null && msgTime != null) {
        if (msgTime.isBefore(clearedTime)) return;
      }
    }

    if (!mounted) return;

    final type = newMessage['type']?.toString();
    if (type == 'mic_emoji') {
      _rb._playMicEmojiFromMessage(newMessage);
      return;
    }

    if (type == 'gift') {
      // Same funnel as the socket copy: it drops the row when room_gift already
      // posted this gift, and parks a lucky line until its roll stops.
      _rb._appendGiftChatMessages([newMessage]);

      // Socket room_gift already played FX. Re-triggering from postgres
      // chat inserts made gifts replay late in busy rooms.
      final batchId = metadata is Map
          ? metadata['animation_batch_id']?.toString() ?? ''
          : '';
      if (batchId.isNotEmpty && _rb._giftFlightController.hasPlayed(batchId)) {
        return;
      }
      if (batchId.isNotEmpty) {
        _rb._seenBroadcastEventIds.add('gift_$batchId');
      }
      _rb._triggerGiftAnimation(newMessage);
      return;
    }

    _rb._tryAppendChatMessage(newMessage);
  }

  Future<void> _persistRoomMessage(Map<String, dynamic> row) async {
    try {
      await Supabase.instance.client.from('room_messages').insert(row);
    } catch (e) {
      debugPrint('room_messages insert failed: $e');
    }
  }

  Widget _buildReconnectBanner() {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orangeAccent,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Reconnecting…',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
