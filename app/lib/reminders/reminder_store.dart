import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';

import '../journal/entry.dart';
import 'announcer.dart';
import 'reminder.dart';

/// The reminders, where they are kept, and what the phone has been asked
/// to announce.
///
/// They are kept as `reminders.json` in the journal folder, so a copy of
/// the journal carries them too. With no file they last only as long as
/// the app runs.
class ReminderStore extends ChangeNotifier {
  /// How many of each reminder's coming days are handed to the phone, and
  /// how many announcements in all. Android keeps only so many per app,
  /// and each opening of the app tops them up.
  static const perReminder = 6;
  static const announcedAtMost = 60;

  static final _random = Random.secure();

  static ({double latitude, double longitude})? _nowhere() => null;

  final File? file;
  final Announcer announcer;
  final Duration utcOffset;
  final DateTime Function() _now;

  /// Each date's own offset: the phone's on that day where the clocks
  /// change, else [utcOffset] (tests, and anywhere they do not).
  final Duration Function(CivilDate date)? zoneOffset;

  Duration offsetOn(CivilDate date) => zoneOffset?.call(date) ?? utcOffset;

  /// The minute of [date] [reminder] falls at: by the sun at the place,
  /// on that day, for one reckoned by the sun; else its clock time.
  int minuteOf(Reminder reminder, CivilDate date) =>
      reminder.minuteOn(date, place: placeOf(), utcOffset: offsetOn(date)) ??
      reminder.minuteOfDay;

  /// The place the sun's reminders are worked out for; none, and they
  /// are not announced.
  final ({double latitude, double longitude})? Function() placeOf;
  final _reminders = <Reminder>[];

  // Which days have reminders, as far as has been asked.
  final _onDay = <int, List<Reminder>>{};

  ReminderStore({
    this.file,
    this.announcer = const SilentAnnouncer(),
    required this.utcOffset,
    DateTime Function()? now,
    ({double latitude, double longitude})? Function()? placeOf,
    this.zoneOffset,
  }) : _now = now ?? DateTime.now,
       placeOf = placeOf ?? _nowhere {
    _read();
    announce();
  }

  void _read() {
    _reminders.clear();
    final file = this.file;
    if (file == null || !file.existsSync()) return;
    try {
      _reminders.addAll([
        for (final item in (jsonDecode(
          file.readAsStringSync(),
        ) as List).cast<Map<String, dynamic>>())
          ?Reminder.fromJson(item),
      ]);
    } catch (_) {
      // A file that cannot be read is left where it is, untouched, until
      // something is saved over it.
    }
  }

  /// Reads the reminders afresh from their file: for after a sync has
  /// changed it underneath.
  void reload() {
    _read();
    _revision++;
    _onDay.clear();
    _inMonth.clear();
    announce();
    notifyListeners();
  }

  /// Goes up by one with every change.
  int get revision => _revision;
  var _revision = 0;

  List<Reminder> get reminders => List.unmodifiable(_reminders);

  Reminder? reminder(String id) =>
      _reminders.where((r) => r.id == id).firstOrNull;

  /// The reminders switched on that fall on [date], earliest first.
  List<Reminder> on(CivilDate date) => _onDay.putIfAbsent(
    date.dayNumber,
    () => [
      for (final reminder in _reminders)
        if (reminder.enabled &&
            reminder.occursOn(date, utcOffset: utcOffset, offsetOn: offsetOn))
          reminder,
    ]..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay)),
  );

  /// Of [categories], those with a reminder on [date], the one with the
  /// earliest reminder first, each once: the day's dots on the calendar.
  /// A reminder whose category is not among them counts under the first.
  List<JournalCategory> marksOn(
    CivilDate date,
    List<JournalCategory> categories,
  ) {
    if (categories.isEmpty) return const [];
    final found = <JournalCategory>{};
    for (final reminder in on(date)) {
      found.add(
        categories.where((c) => c.id == reminder.categoryId).firstOrNull ??
            categories.first,
      );
    }
    return found.toList();
  }

  // Which categories have a reminder in a month, as far as has been asked.
  final _inMonth = <int, List<String>>{};

  /// Of [categories], those with a reminder in a month, the one whose
  /// first falls earliest first: the month's dots on the year grid.
  List<JournalCategory> marksIn(
    int year,
    int month,
    List<JournalCategory> categories,
  ) => marksBetween(
    CivilDate(year, month, 1),
    CivilDate.daysInMonth(year, month),
    categories,
  );

  /// The same for the [days] days from [first]: a month of whatever
  /// system the calendar is counting in.
  List<JournalCategory> marksBetween(
    CivilDate first,
    int days,
    List<JournalCategory> categories,
  ) {
    if (categories.isEmpty) return const [];
    final ids = _inMonth.putIfAbsent(first.dayNumber * 64 + days, () {
      final found = <String>{};
      for (var day = 0; day < days; day++) {
        for (final reminder in on(first.addDays(day))) {
          found.add(reminder.categoryId ?? '');
        }
      }
      return found.toList();
    });
    final found = <JournalCategory>{};
    for (final id in ids) {
      found.add(
        categories.where((c) => c.id == id).firstOrNull ?? categories.first,
      );
    }
    return found.toList();
  }

  /// The next day [reminder] falls on, today included, or null if it has
  /// none left.
  CivilDate? nextOf(Reminder reminder) => reminder
      .occurrences(
        CivilDate.fromDateTime(_now()),
        utcOffset: utcOffset,
        offsetOn: offsetOn,
      )
      .firstOrNull;

  /// Gives a new reminder the moment it is first saved, in every
  /// calendar (`MomentStamp`); set by the app.
  Map<String, String?> Function()? stamp;

  /// Saves [reminder] and returns it as saved. One with no id is new.
  Reminder save(Reminder reminder) {
    var saved = reminder;
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (reminder.id.isEmpty || index < 0) {
      saved = reminder.copyWith(
        id: reminder.id.isEmpty ? _newId() : reminder.id,
        // A new one takes the moment it was first saved.
        moment: reminder.id.isEmpty && reminder.moment.isEmpty && stamp != null
            ? stamp!()
            : null,
      );
      _reminders.add(saved);
    } else {
      _reminders[index] = saved;
    }
    _changed();
    return saved;
  }

  void delete(String id) {
    _reminders.removeWhere((r) => r.id == id);
    _changed();
  }

  /// How many reminders are in category [categoryId].
  int countIn(String categoryId) =>
      _reminders.where((r) => r.categoryId == categoryId).length;

  /// Deletes every reminder in category [categoryId]: for when the
  /// category itself is deleted.
  void deleteIn(String categoryId) {
    if (countIn(categoryId) == 0) return;
    _reminders.removeWhere((r) => r.categoryId == categoryId);
    _changed();
  }

  /// Takes tag [id] off every reminder that has it: for when the tag is
  /// deleted.
  void untag(String id) {
    if (!_reminders.any((r) => r.tags.contains(id))) return;
    for (var i = 0; i < _reminders.length; i++) {
      final reminder = _reminders[i];
      if (!reminder.tags.contains(id)) continue;
      _reminders[i] = reminder.copyWith(
        tags: [
          for (final t in reminder.tags)
            if (t != id) t,
        ],
      );
    }
    _changed();
  }

  /// How many reminders carry tag [id].
  int countTagged(String id) =>
      _reminders.where((r) => r.tags.contains(id)).length;

  /// Deletes the reminders with these [ids] in one go.
  void deleteAll(Set<String> ids) {
    if (!_reminders.any((r) => ids.contains(r.id))) return;
    _reminders.removeWhere((r) => ids.contains(r.id));
    _changed();
  }

  /// Adds the [incoming] reminders that are not here already, by id, and
  /// returns how many that was.
  int merge(List<Reminder> incoming, {Map<String, String> tagIds = const {}}) {
    final fresh = [
      for (final reminder in incoming)
        if (this.reminder(reminder.id) == null)
          tagIds.isEmpty
              ? reminder
              : reminder.copyWith(
                  tags: {for (final t in reminder.tags) tagIds[t] ?? t}
                      .toList(),
                ),
    ];
    if (fresh.isEmpty) return 0;
    _reminders.addAll(fresh);
    _changed();
    return fresh.length;
  }

  /// Whether the phone will show notifications; asks the user if it has
  /// to.
  Future<bool> askAllowed() => announcer.askAllowed();

  String _newId() {
    while (true) {
      final id = _random.nextInt(0x1000000).toRadixString(16).padLeft(6, '0');
      if (reminder(id) == null) return id;
    }
  }

  void _changed() {
    _revision++;
    _onDay.clear();
    _inMonth.clear();
    final file = this.file;
    if (file != null) {
      file.parent.createSync(recursive: true);
      final draft = File('${file.path}.tmp')
        ..writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert([for (final reminder in _reminders) reminder.toJson()])}\n',
          flush: true,
        );
      draft.renameSync(file.path);
    }
    announce();
    notifyListeners();
  }

  /// What the phone should announce from now on: the coming days of every
  /// reminder that is switched on, soonest first.
  /// What else there is to announce besides the reminders: the end of
  /// a practice timed down.
  List<Announcement> Function()? alsoAnnounce;

  List<Announcement> upcoming() {
    final now = _now();
    final today = CivilDate.fromDateTime(now);
    final all = <Announcement>[
      for (final extra in alsoAnnounce?.call() ?? const <Announcement>[])
        if (extra.when.isAfter(now)) extra,
    ];
    for (final reminder in _reminders) {
      if (!reminder.enabled) continue;
      final mine = <Announcement>[];
      for (final date in reminder.occurrences(
        today,
        utcOffset: utcOffset,
        offsetOn: offsetOn,
        // One more, in case today's has already passed.
        count: perReminder + 1,
      )) {
        final minute = reminder.minuteOn(
          date,
          place: placeOf(),
          utcOffset: DateTime(
            date.year,
            date.month,
            date.day,
            12,
          ).timeZoneOffset,
        );
        if (minute == null) continue;
        final when = DateTime(
          date.year,
          date.month,
          date.day,
          minute ~/ 60,
          minute % 60,
        );
        if (!when.isAfter(now)) continue;
        final clock =
            '${(minute ~/ 60).toString().padLeft(2, '0')}:'
            '${(minute % 60).toString().padLeft(2, '0')}';
        mine.add(
          Announcement(
            // The same reminder on the same day always has the same id.
            id: Object.hash(reminder.id, date.dayNumber) & 0x7fffffff,
            when: when,
            title: reminder.title,
            body: '${Weton.of(date)} · $clock',
          ),
        );
      }
      all.addAll(mine.take(perReminder));
    }
    all.sort((a, b) => a.when.compareTo(b.when));
    return all.take(announcedAtMost).toList();
  }

  /// Hands the phone what to announce. Done at every start and after every
  /// change.
  Future<void> announce() => announcer.replaceAll(upcoming());
}

/// Gives the subtree the [ReminderStore]. Widgets that read it rebuild
/// when a reminder changes.
class ReminderScope extends InheritedNotifier<ReminderStore> {
  const ReminderScope({
    super.key,
    required ReminderStore super.notifier,
    required super.child,
  });

  static ReminderStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReminderScope>()!.notifier!;
}
