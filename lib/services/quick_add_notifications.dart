import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class QuickAddNotifications {
  QuickAddNotifications._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final addRequests = ValueNotifier<int>(0);
  static bool _initialized = false;

  static Future<void> showBudgetAlert({
    required int percentage,
    required bool overBudget,
  }) async {
    if (!Platform.isAndroid || !_initialized) return;
    try {
      await _plugin.show(
        id: 2,
        title: 'Judgy budget',
        body: 'You have reached $percentage% of your monthly budget.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'judgy_budget_alerts',
            'Budget alerts',
            channelDescription: 'Monthly budget milestones.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {
      /* Notification permission or service failure must not affect saved spending. */
    }
  }

  static Future<String?> initialize() async {
    if (!Platform.isAndroid) return null;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload == 'add') addRequests.value++;
        },
      );
      _initialized = true;
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final allowed = await android?.requestNotificationsPermission();
      if (allowed != false) {
        await _plugin.show(
          id: 1,
          title: 'Judgy',
          body: 'Tap to add an expense',
          payload: 'add',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'judgy_quick_add',
              'Quick add',
              channelDescription: 'Add spending from the notification shade.',
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              autoCancel: false,
            ),
          ),
        );
      }
      final details = await _plugin.getNotificationAppLaunchDetails();
      return details?.didNotificationLaunchApp == true
          ? details?.notificationResponse?.payload
          : null;
    } catch (_) {
      return null;
    }
  }
}
