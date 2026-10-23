import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// One notification waiting to be shown.
class Announcement {
  final int id;

  /// When, in the phone's own time.
  final DateTime when;
  final String title;
  final String body;

  const Announcement({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });
}

/// Shows reminders as notifications.
abstract class Announcer {
  /// Whether the phone lets the app show notifications; asks the user the
  /// first time, where the phone needs asking.
  Future<bool> askAllowed();

  /// Replaces everything waiting to be shown with [announcements].
  Future<void> replaceAll(List<Announcement> announcements);
}

/// Shows nothing. For tests, and wherever notifications cannot be had.
class SilentAnnouncer implements Announcer {
  const SilentAnnouncer();

  @override
  Future<bool> askAllowed() async => true;

  @override
  Future<void> replaceAll(List<Announcement> announcements) async {}
}

/// Hands notifications to the phone, to be shown at their times whether or
/// not the app is running, and again after the phone restarts.
///
/// They are asked for to the minute. Left to choose its own moment the
/// phone allows itself up to an hour's delay, which is no good for a
/// reminder set for half past seven. Android lets a calendar app ask for
/// the exact minute without troubling the user; where a phone refuses all
/// the same, the reminder is still set, to arrive when the phone sees fit.
class PhoneAnnouncer implements Announcer {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'The reminders you have set in Candra',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _prepare() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher_monochrome'),
        // Nothing is asked for at start: only when a reminder is first
        // saved, through askAllowed.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> askAllowed() async {
    try {
      await _prepare();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      if (await _android?.areNotificationsEnabled() ?? false) return true;
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> replaceAll(List<Announcement> announcements) async {
    try {
      await _prepare();
      // Only what is waiting and no longer wanted is taken back. What has
      // already been shown stays where it is (a reminder not yet read, the
      // practice under way): this runs in the background too, and must
      // never clear what the user has not seen.
      final wanted = {for (final a in announcements) a.id};
      for (final pending in await _plugin.pendingNotificationRequests()) {
        if (!wanted.contains(pending.id)) await _plugin.cancel(id: pending.id);
      }
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      for (final announcement in announcements) {
        await _plugin.zonedSchedule(
          id: announcement.id,
          // An instant, not a wall-clock time: nothing here repeats by
          // itself, and everything is set again each time the app opens
          // and each time the background task runs. The same id replaces
          // what was waiting under it, so doing this twice changes nothing.
          scheduledDate: tz.TZDateTime.from(announcement.when, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          title: announcement.title,
          body: announcement.body,
        );
      }
    } catch (_) {
      // A phone that will not take them is no reason to stop the app.
    }
  }
}
