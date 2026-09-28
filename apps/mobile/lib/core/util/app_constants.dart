import 'package:flutter/foundation.dart';
import 'package:sk_live/core/services/room_deep_link_service.dart';

class AppConstants {
  AppConstants._();

  static const String roomSharePublicBaseUrl = 'https://rave-land.vercel.app';

  static const String roomShareEdgeUrl =
      'https://api.skliveparty.online/functions/v1/room-link';
  static const String roomShareStorageUrl =
      'https://api.skliveparty.online/storage/v1/object/public/deep_links/room.html';
  static const bool useSupabaseShareBackend = false;

  static String roomShareLink(String roomId) {
    if (useSupabaseShareBackend) {
      final page = roomShareEdgeUrl;
      return RoomDeepLinkService.buildShareWebLink(roomId, page);
    }
    return RoomDeepLinkService.buildPublicRoomLink(
      roomId,
      roomSharePublicBaseUrl,
    );
  }

  static String roomDeepLink(String roomId) =>
      RoomDeepLinkService.buildRoomLink(roomId);

  static const String supabaseUrl = 'https://api.skliveparty.online';
  static const String supabaseAnonKey =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc4OTM1Njg0MCwiZXhwIjo0OTQ1MDMwNDQwLCJyb2xlIjoiYW5vbiJ9.EWvuDd6qv4UxGNXzWnSWQGNXi9NBrD0Y-_XH3bdJwKM';
  static const String googleWebClientId =
      '414833564088-ju3bgj5slnu9rl8k31gb9f4hrp28mvia.apps.googleusercontent.com';

  static const bool useRealtimeGateway = true;
  static const bool useDmGateway = true;

  static const int dmHydrateLimit = 100;

  static const String realtimeGatewayUrl = 'https://gateway.skliveparty.online';

  static String get maintenanceBypassToken => kDebugMode
      ? const String.fromEnvironment('MAINTENANCE_BYPASS_TOKEN')
      : '';

  static const bool enableGlobalWinSvgaBroadcast = true;

  static const bool useGatewayLuckyEngine = true;

  static const bool enableWinBonusNotifications = false;

  static const bool useRoomContributionMockData = false;
}
