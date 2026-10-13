import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../models/review_settings.dart';

class ReviewNotificationService {
  static const _notificationId = 7401;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // The timezone package falls back to UTC on unsupported platforms.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  static Future<void> apply(ReviewSettings settings) async {
    await initialize();
    if (!settings.notificationsEnabled) {
      await _plugin.cancel(id: _notificationId);
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      settings.notificationHour,
      settings.notificationMinute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'study_reviews',
        'Revisões de estudo',
        channelDescription: 'Lembretes dos cards e questões pendentes',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Hora da sua revisão',
      body: _bodyFor(settings.reviewMode),
      scheduledDate: next,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'review-plan',
    );
  }

  static String _bodyFor(String mode) => switch (mode) {
        'difficult' => 'Revise os cards marcados como difíceis.',
        'all' => 'Faça uma revisão completa dos seus cards.',
        _ => 'Você tem revisões pendentes para hoje.',
      };
}
