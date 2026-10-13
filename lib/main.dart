import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/review_notification_service.dart';
import 'core/services/review_settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReviewNotificationService.initialize();
  await ReviewNotificationService.apply(await ReviewSettingsService().load());
  runApp(const ProviderScope(child: DailyEnglishApp()));
}
