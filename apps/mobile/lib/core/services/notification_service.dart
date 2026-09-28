import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sk_live/firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/services/device_id_service.dart';
import 'package:sk_live/features/home/presentation/widgets/room_admin_invite_dialog.dart';
import 'package:sk_live/features/home/presentation/widgets/cp_proposal_invite_dialog.dart';
import 'package:sk_live/features/home/presentation/widgets/room_seat_invite_dialog.dart';
import 'package:sk_live/features/home/presentation/widgets/buddy_invite_dialog.dart';
import 'package:sk_live/features/auth/presentation/pages/reseller_screen.dart';
import 'package:sk_live/features/wallet/presentation/pages/bill_records_screen.dart';
import 'package:go_router/go_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static String? activeConversationId;

  static Future<void> initialize() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permissions');
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(details.payload!);
            _handleNotificationClick(data);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification?.title}',
        );
        _showLocalNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened app: ${message.data}');
      _handleNotificationClick(message.data);
    });

    String? token = await _messaging.getToken();
    if (kDebugMode) debugPrint('FCM Token: $token');

    await _messaging.subscribeToTopic('all');
    debugPrint('Subscribed to "all" topic');
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static void _showLocalNotification(RemoteMessage message) {
    if (message.data['type'] == 'chat' ||
        message.data['conversation_id'] != null) {
      final incomingConvId = message.data['conversation_id'];
      if (incomingConvId != null && incomingConvId == activeConversationId) {
        debugPrint(
          'User is already on this chat screen, skipping local notification.',
        );
        return;
      }
    }

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  static void _handleNotificationClick(Map<String, dynamic> data) {
    debugPrint('Handling notification click with data: $data');

    if (data['type'] == 'room_admin_invite') {
      final invitationId = data['invitation_id']?.toString();
      if (invitationId != null) {
        openRoomAdminInviteAcceptScreen(null, invitationId: invitationId);
      }
      return;
    }

    if (data['type'] == 'buddy_invite') {
      final invitationId = data['invitation_id']?.toString();
      if (invitationId != null) {
        openBuddyInviteAcceptScreen(null, invitationId: invitationId);
      }
      return;
    }

    if (data['type'] == 'cp_proposal') {
      final proposalId = data['proposal_id']?.toString();
      if (proposalId != null) {
        openCpProposalAcceptScreen(null, proposalId: proposalId);
      }
      return;
    }

    if (data['type'] == 'room_seat_invite') {
      final invitationId = data['invitation_id']?.toString();
      if (invitationId != null) {
        openRoomSeatInviteAcceptScreen(null, invitationId: invitationId);
      }
      return;
    }

    final type = data['type']?.toString();
    if (type == 'room_reward_box' || type == 'room_invite') {
      final roomId = data['room_id']?.toString();
      if (roomId != null && roomId.isNotEmpty) {
        final context = AppRouter.navigatorKey.currentContext;
        if (context != null) {
          context.go('${AppRouter.roomDeepLink}/$roomId');
        }
      }
      return;
    }

    if (type == 'admin_gift' || data['route']?.toString() == '/inventory') {
      final context = AppRouter.navigatorKey.currentContext;
      if (context != null) {
        context.push(AppRouter.inventory);
      }
      return;
    }

    if (type == 'withdrawal_request') {
      final context = AppRouter.navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ResellerScreen(initialTab: 1),
          ),
        );
      }
      return;
    }

    if (type == 'withdrawal_approved' ||
        type == 'withdrawal_rejected' ||
        type == 'withdrawal_completed') {
      final context = AppRouter.navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const BillRecordsScreen()));
      }
      return;
    }

    if (data['type'] == 'chat' || data['conversation_id'] != null) {
      final context = AppRouter.navigatorKey.currentContext;
      if (context != null) {
        context.push(
          AppRouter.chat,
          extra: {
            'conversationId': data['conversation_id'],
            'targetUserId': data['sender_id'],
            'targetUsername': data['sender_name'] ?? 'User',
            'targetAvatar': data['sender_avatar'],
          },
        );
      }
    }
  }

  static Future<void> saveTokenToDatabase(String userId) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await Supabase.instance.client
            .from('users')
            .update({'fcm_token': token})
            .eq('id', userId);
        debugPrint('FCM Token saved to Supabase for user: $userId');

        try {
          final signals = await DeviceIdService.collectSignals();
          await Supabase.instance.client.rpc(
            'register_my_device',
            params: {
              'p_device_id': signals['install_id'],
              'p_android_id': signals['android_id'],
              'p_fcm_token': token,
            },
          );
        } catch (e) {
          debugPrint('Device re-register after FCM save failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
}
