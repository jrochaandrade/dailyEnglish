import 'package:shared_preferences/shared_preferences.dart';
import '../../models/review_settings.dart';
import 'review_notification_service.dart';

class ReviewSettingsService {
  static const _enabledKey = 'review_notifications_enabled';
  static const _hourKey = 'review_notification_hour';
  static const _minuteKey = 'review_notification_minute';
  static const _modeKey = 'review_mode';

  Future<ReviewSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReviewSettings(
      notificationsEnabled: prefs.getBool(_enabledKey) ?? true,
      notificationHour: prefs.getInt(_hourKey) ?? 9,
      notificationMinute: prefs.getInt(_minuteKey) ?? 0,
      reviewMode: prefs.getString(_modeKey) ?? 'due',
    );
  }

  Future<void> save(ReviewSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.notificationsEnabled);
    await prefs.setInt(_hourKey, settings.notificationHour);
    await prefs.setInt(_minuteKey, settings.notificationMinute);
    await prefs.setString(_modeKey, settings.reviewMode);
    await ReviewNotificationService.apply(settings);
  }
}
