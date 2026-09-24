import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseNotifications {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'chapaturepuesto_notifications',
    'Notificaciones de ChapaTuRepuesto',
    description: 'Notificaciones de pedidos y alertas.',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
  settings: settings,
);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint(
        'FCM recibido en primer plano: '
        '${message.notification?.title} - '
        '${message.notification?.body}',
      );

      final notification = message.notification;

      if (notification != null) {
        await _localNotifications.show(
  id: notification.hashCode,
  title: notification.title ?? 'ChapaTuRepuesto',
  body: notification.body ?? '',
  notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'chapaturepuesto_notifications',
              'Notificaciones de ChapaTuRepuesto',
              channelDescription: 'Notificaciones de pedidos y alertas.',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        'Notificación FCM abierta: ${message.notification?.title}',
      );
    });
  }
}