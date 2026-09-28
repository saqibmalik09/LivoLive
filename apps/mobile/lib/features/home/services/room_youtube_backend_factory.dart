import 'dart:io';

import 'room_youtube_android_backend.dart';
import 'room_youtube_iframe_backend.dart';
import 'room_youtube_player_backend.dart';

const bool _useAndroidNativePlayer = false;

RoomYoutubePlayerBackend createRoomYoutubePlayerBackend() {
  if (Platform.isAndroid && _useAndroidNativePlayer) {
    return RoomYoutubeAndroidBackend();
  }
  return RoomYoutubeIframeBackend();
}
