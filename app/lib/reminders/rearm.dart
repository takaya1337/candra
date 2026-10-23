import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../practice/practice.dart';
import '../strings.dart';
import 'announcer.dart';
import '../sky_place.dart';
import 'reminder_store.dart';

/// Where the app keeps what outlives it: the settings a background task
/// also reads.
const languageKey = 'language';
const practiceStartedKey = 'practice_started';
const practiceCategoryKey = 'practice_category';
const practiceLengthKey = 'practice_length';
const practiceEndedKey = 'practice_ended';

/// The task that hands the phone the reminders' coming days again while
/// the app stays closed. Its name is also what iOS knows it by
/// (`BGTaskSchedulerPermittedIdentifiers` in `Info.plist`).
const rearmTask = 'com.suryamajapahit.candra.rearm';

/// How often the phone is asked to run it. Each run hands over the next
/// [ReminderStore.perReminder] days of every reminder, so twice a day is
/// far inside the window, and a run missed costs nothing.
const rearmEvery = Duration(hours: 12);

/// Asks the phone to run [rearmTask] every [rearmEvery], whether or not
/// the app is opened. Android's WorkManager keeps it through restarts and
/// runs it close to its time; iOS runs it when it sees fit, and may not
/// at all for an app long unused, so there it is best effort. Asking
/// again keeps the task already asked for.
Future<void> scheduleRearm() async {
  try {
    await Workmanager().initialize(rearmDispatcher);
    await Workmanager().registerPeriodicTask(
      rearmTask,
      rearmTask,
      frequency: rearmEvery,
      // A changed schedule takes the place of the one asked for before.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
    // Only in a build made to check the background path on a phone: one
    // run of the same task, twenty seconds on, with the app closed.
    if (_rearmNow) {
      await Workmanager().registerOneOffTask(
        'rearm-now',
        rearmTask,
        initialDelay: const Duration(seconds: 20),
      );
    }
  } catch (_) {
    // A phone with no such service still gets its reminders topped up
    // each time the app is opened.
  }
}

const _rearmNow = bool.fromEnvironment('REARM_NOW');

/// What the phone runs in the background: the reminders read from their
/// file and handed over again, as the app does when it opens.
@pragma('vm:entry-point')
void rearmDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final root = await getApplicationSupportDirectory();
      final preferences = await SharedPreferences.getInstance();
      final announcements = announcementsFor(
        root: root,
        preferences: preferences,
      );
      await PhoneAnnouncer().replaceAll(announcements);
      if (_rearmNow) {
        // ignore: avoid_print
        print('CANDRA REARM ${announcements.length} at ${DateTime.now()}');
      }
    } catch (_) {
      // Nothing worse than not topping up this time.
    }
    return true;
  });
}

/// Everything the app would hand the phone now, worked out from what it
/// keeps on disk alone: every switched-on reminder's coming days, and the
/// end of a practice being timed down. The same list the app makes when
/// it opens, so running this again and again changes nothing.
List<Announcement> announcementsFor({
  required Directory root,
  required SharedPreferences preferences,
  DateTime Function()? now,
}) {
  final clock = now ?? DateTime.now;
  final journal = '${root.path}/journal';
  final latitude = preferences.getDouble(SkyPlace.latitudeKey);
  final longitude = preferences.getDouble(SkyPlace.longitudeKey);
  final store = ReminderStore(
    // Each day by its own clock, where the clocks change.
    zoneOffset: (d) => DateTime(d.year, d.month, d.day, 12).timeZoneOffset,
    placeOf: () => latitude == null || longitude == null
        ? null
        : (latitude: latitude, longitude: longitude),
    file: File('$journal/reminders.json'),
    utcOffset: clock().timeZoneOffset,
    now: clock,
  );
  final practice = _practice(preferences);
  final ends = practice?.endsAt;
  if (practice != null && ends != null) {
    final language = AppLanguage.values
        .where((l) => l.name == preferences.getString(languageKey))
        .firstOrNull;
    store.alsoAnnounce = () => [
      Announcement(
        id: 1,
        when: ends.toLocal(),
        title: Strings(language ?? AppLanguage.en).practiceComplete,
        body: _categoryName(journal, practice.categoryId),
      ),
    ];
  }
  final announcements = store.upcoming();
  store.dispose();
  return announcements;
}

Practice? _practice(SharedPreferences preferences) {
  final started = preferences.getInt(practiceStartedKey);
  final category = preferences.getString(practiceCategoryKey);
  if (started == null || category == null) return null;
  final length = preferences.getInt(practiceLengthKey);
  final ended = preferences.getInt(practiceEndedKey);
  return Practice(
    startedAt: DateTime.fromMillisecondsSinceEpoch(started, isUtc: true),
    categoryId: category,
    length: length == null ? null : Duration(seconds: length),
    endedAt: ended == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ended, isUtc: true),
  );
}

String _categoryName(String journal, String id) {
  try {
    final list =
        jsonDecode(File('$journal/categories.json').readAsStringSync()) as List;
    for (final item in list.cast<Map<String, dynamic>>()) {
      if (item['id'] == id) return item['name'] as String? ?? '';
    }
  } catch (_) {}
  return '';
}
