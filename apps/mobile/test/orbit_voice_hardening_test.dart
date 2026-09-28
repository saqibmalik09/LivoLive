import 'package:flutter_test/flutter_test.dart';
import 'package:sk_live/core/services/orbit_voice_session_service.dart';
import 'package:sk_live/core/services/room_floating_bubble_service.dart';
import 'package:sk_live/core/services/room_minimized_keepalive.dart';

void main() {
  group('OrbitVoiceSessionService', () {
    test('dead session reports not connected', () {
      expect(OrbitVoiceSessionService.isConnected, isFalse);
      expect(OrbitVoiceSessionService.canPublishNow, isFalse);
      expect(OrbitVoiceSessionService.hasLiveMicTrack, isFalse);
      expect(OrbitVoiceSessionService.connectedSkLiveRoomId, isNull);
    });
  });

  group('RoomFloatingBubbleService fail-closed helpers', () {
    tearDown(() {
      RoomFloatingBubbleService.intentionalHidePending = false;
      RoomFloatingBubbleService.overlayConfirmedActive = false;
      RoomFloatingBubbleService.cacheSession(null);
    });

    test('intentional hide suppresses bubble_removed hard-exit', () {
      RoomFloatingBubbleService.intentionalHidePending = true;
      RoomFloatingBubbleService.overlayConfirmedActive = true;
      expect(RoomFloatingBubbleService.consumeUnexpectedRemoval(), isFalse);
      // Task-removed + onDestroy can emit twice; suppression is a window.
      expect(RoomFloatingBubbleService.intentionalHidePending, isTrue);
      expect(RoomFloatingBubbleService.consumeUnexpectedRemoval(), isFalse);
      expect(RoomFloatingBubbleService.overlayConfirmedActive, isFalse);
    });

    test('unexpected removal with active overlay triggers hard-exit', () {
      RoomFloatingBubbleService.intentionalHidePending = false;
      RoomFloatingBubbleService.overlayConfirmedActive = true;
      expect(RoomFloatingBubbleService.consumeUnexpectedRemoval(), isTrue);
      expect(RoomFloatingBubbleService.overlayConfirmedActive, isFalse);
    });

    test('cached session without confirmed overlay does not hard-exit', () {
      RoomFloatingBubbleService.intentionalHidePending = false;
      RoomFloatingBubbleService.overlayConfirmedActive = false;
      RoomFloatingBubbleService.cacheSession({'id': 'room-1'});
      expect(RoomFloatingBubbleService.consumeUnexpectedRemoval(), isFalse);
    });
  });

  group('RoomMinimizedKeepAlive voice snapshot', () {
    tearDown(RoomMinimizedKeepAlive.stop);

    test('saveVoiceState persists seat/mute/publish flags', () {
      RoomMinimizedKeepAlive.saveVoiceState(
        seatIndex: 3,
        isMuted: false,
        orbitCanPublish: true,
        localPublishing: true,
      );
      expect(RoomMinimizedKeepAlive.voiceSeatIndex, 3);
      expect(RoomMinimizedKeepAlive.voiceMuted, isFalse);
      expect(RoomMinimizedKeepAlive.voiceOrbitCanPublish, isTrue);
      expect(RoomMinimizedKeepAlive.voiceLocalPublishing, isTrue);
    });

    test('stop clears voice snapshot', () {
      RoomMinimizedKeepAlive.saveVoiceState(
        seatIndex: 1,
        isMuted: true,
        orbitCanPublish: false,
        localPublishing: false,
      );
      RoomMinimizedKeepAlive.stop();
      expect(RoomMinimizedKeepAlive.voiceSeatIndex, isNull);
      expect(RoomMinimizedKeepAlive.roomId, isNull);
      expect(RoomMinimizedKeepAlive.isActive, isFalse);
    });
  });
}
