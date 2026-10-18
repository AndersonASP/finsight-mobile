import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../offline/offline_store.dart';
import 'reminder_planner.dart';

/// The device side of bill reminders. Overridden with a fake in tests.
abstract class ReminderNotifications {
  /// Sets up the plugin; [onOpen] receives the due date of a tapped reminder.
  Future<void> init(void Function(DateTime dueDate) onOpen);

  /// Asks the OS for permission to show notifications. True when granted.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);

  Future<void> cancelAll();

  /// Schedules [reminder] alone, without touching the others (debug testing).
  Future<void> scheduleOne(PlannedReminder reminder);

  /// Due date of the reminder that launched the app, if any.
  Future<DateTime?> launchDueDate();

  /// Shows a notification right away (e.g. "Quero comprar": agora cabe).
  /// Does nothing without permission.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  });
}

final reminderNotificationsProvider = Provider<ReminderNotifications>((ref) {
  return LocalReminderNotifications();
});

const _payloadPrefix = 'bills:';

DateTime? _dueDateFromPayload(String? payload) {
  if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
  return DateTime.tryParse(payload.substring(_payloadPrefix.length));
}

class LocalReminderNotifications implements ReminderNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _details = NotificationDetails(
    iOS: DarwinNotificationDetails(threadIdentifier: 'bills'),
    android: AndroidNotificationDetails(
      'bills',
      'Contas a pagar',
      channelDescription: 'Lembretes de vencimento de contas',
    ),
  );

  @override
  Future<void> init(void Function(DateTime dueDate) onOpen) async {
    if (_initialized) return;
    _initialized = true;
    tz_data.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (error) {
      debugPrint('Could not resolve local timezone, using UTC: $error');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        // Permission is asked explicitly from "Contas a pagar", never at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final dueDate = _dueDateFromPayload(response.payload);
        if (dueDate != null) onOpen(dueDate);
      },
    );
  }

  @override
  Future<bool> requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    // Pending only: an alert already delivered (e.g. "agora cabe") stays.
    await _plugin.cancelAllPendingNotifications();
    for (final reminder in reminders) {
      await scheduleOne(reminder);
    }
  }

  @override
  Future<void> scheduleOne(PlannedReminder reminder) {
    return _plugin.zonedSchedule(
      id: reminder.id,
      scheduledDate: tz.TZDateTime(
        tz.local,
        reminder.when.year,
        reminder.when.month,
        reminder.when.day,
        reminder.when.hour,
        reminder.when.minute,
        reminder.when.second,
      ),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: reminder.title,
      body: reminder.body,
      payload: '$_payloadPrefix${dateKey(reminder.dueDate)}',
    );
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  static const _wishlistDetails = NotificationDetails(
    iOS: DarwinNotificationDetails(threadIdentifier: 'wishlist'),
    android: AndroidNotificationDetails(
      'wishlist',
      'Quero comprar',
      channelDescription: 'Avisa quando uma compra desejada passa a caber',
    ),
  );

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: _wishlistDetails,
  );

  @override
  Future<DateTime?> launchDueDate() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return _dueDateFromPayload(details!.notificationResponse?.payload);
  }
}
