import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class QuickAddNotifications {
  QuickAddNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> showBudgetAlert({
    required int percentage,
    required bool overBudget,
  }) async {
    if (!Platform.isAndroid) return;

    await _plugin.show(
      id: 2,
      title: 'Judgy budget',
      body: overBudget
          ? 'You are $percentage% of your monthly budget.'
          : 'You have used $percentage% of your monthly budget.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'judgy_quick_add',
          'Judgy quick add',
          channelDescription:
              'Quickly add an expense from the notification shade.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<String?> initialize() async {
    if (!Platform.isAndroid) return null;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

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
