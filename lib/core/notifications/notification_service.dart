import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Notification payload handler
      },
    );

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> showChapterUpdateNotification({
    required int id,
    required String mangaTitle,
    required String chapterTitle,
    required int newCount,
    String? payload,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'kuroku_chapter_updates',
      'Chapter Updates',
      channelDescription: 'Notifications for newly released manga chapters',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      showWhen: true,
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

    final body = newCount > 1
        ? '$newCount new chapters: $chapterTitle'
        : '1 new chapter: $chapterTitle';

    await _plugin.show(
      id: id,
      title: mangaTitle,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
