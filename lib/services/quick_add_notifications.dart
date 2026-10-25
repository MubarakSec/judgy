import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class QuickAddNotifications {
  QuickAddNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<String?> initialize() async {
    if (!Platform.isAndroid) return null;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: settings);

    const channel = AndroidNotificationChannel(
      'judgy_quick_add',
      'Judgy quick add',
      description: 'Quickly add an expense from the notification shade.',
      importance: Importance.low,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _plugin.show(
      id: 1,
      title: 'Judgy',
      body: 'Tap to add an expense',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'judgy_quick_add',
          'Judgy quick add',
          channelDescription:
              'Quickly add an expense from the notification shade.',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
        ),
      ),
      payload: 'add',
    );

    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }
}
