import 'package:flutter/foundation.dart';
import 'package:sacred_time/sacred_time.dart';

import '../journal/entry.dart';
import '../journal/journal_store.dart';
import '../strings.dart';

/// A practice under way: a sitting, a fast, a vigil. Only when it began,
/// what kind it is and, for one timed down, how long it is to last; how
/// long it has gone on is the clock's business.
class Practice {
  /// The instant it began, in Universal Time.
  final DateTime startedAt;

  /// The journal category it will be written under.
  final String categoryId;

  /// How long it is to last, for a countdown; null for a stopwatch,
  /// which runs until it is stopped.
  final Duration? length;

  /// When it was stopped by hand, in Universal Time: it then waits for
  /// the answer to whether it is written into the journal or discarded.
  final DateTime? endedAt;

  const Practice({
    required this.startedAt,
    required this.categoryId,
    this.length,
    this.endedAt,
  });

  /// How long it has gone on: to [now], or to when it was stopped, or for
  /// a countdown run out, its whole length.
  Duration elapsed(DateTime now) {
    final to = endedAt ?? now.toUtc();
    final gone = to.difference(startedAt);
    final whole = length;
    return whole != null && gone > whole ? whole : gone;
  }

  /// When a countdown runs out, to be announced; null for a stopwatch, and
  /// for one stopped by hand.
  DateTime? get endsAt =>
      length == null || endedAt != null ? null : startedAt.add(length!);

  /// Whether it is over, by hand or by running out, and waits to be
  /// written or discarded.
  bool finished(DateTime now) =>
      endedAt != null ||
      length != null && now.toUtc().difference(startedAt) >= length!;
}

/// The one practice that can be under way, or none.
///
/// It outlasts the app: main keeps it in the phone's preferences, so a
/// practice begun before the app was closed is still running when it is
/// opened again. When it stops it becomes a journal entry, dated when it
/// began, carrying how long it went on, with its start and end written
/// in it and a line left open for what is to be said of it.
abstract final class PracticeTimer {
  static final running = ValueNotifier<Practice?>(null);

  /// The clock; a test puts its own in.
  static DateTime Function() now = DateTime.now;

  /// Starts a stopwatch, or with [length] a countdown.
  static void start(String categoryId, {Duration? length}) {
    if (running.value != null) return;
    running.value = Practice(
      startedAt: now().toUtc(),
      categoryId: categoryId,
      length: length,
    );
  }

  /// Moves the practice under way to another category.
  static void recategorise(String categoryId) {
    final practice = running.value;
    if (practice == null || practice.categoryId == categoryId) return;
    running.value = Practice(
      startedAt: practice.startedAt,
      categoryId: categoryId,
      length: practice.length,
      endedAt: practice.endedAt,
    );
  }

  /// Stops it by hand: it waits, as it stands, to be written or
  /// discarded.
  static void halt() {
    final practice = running.value;
    if (practice == null || practice.endedAt != null) return;
    running.value = Practice(
      startedAt: practice.startedAt,
      categoryId: practice.categoryId,
      length: practice.length,
      endedAt: now().toUtc(),
    );
  }

  /// Ends it and writes it into [journal]. A countdown that has run out
  /// ended when it ran out, however much later this is called. Null if
  /// there was none, or its category is gone.
  ///
  /// [categoryId], where given, is the category it is written under,
  /// chosen as it is written (owner, 21 October 2026); else its own.
  static Entry? stop(
    JournalStore journal,
    Strings strings, {
    String? categoryId,
  }) {
    final practice = running.value;
    if (practice == null) return null;
    final category = categoryId ?? practice.categoryId;
    if (journal.category(category) == null) return null;
    running.value = null;
    final ended = practice.startedAt.add(practice.elapsed(now()));
    // Dated by the clock of the place it began in: the phone's.
    final began = practice.startedAt.toLocal();
    final finish = ended.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    String clock(DateTime at) =>
        '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
    final date = CivilDate(began.year, began.month, began.day);
    final lastDate = CivilDate(finish.year, finish.month, finish.day);
    return journal.save(
      Entry(
        id: '',
        date: date,
        minuteOfDay: began.hour * 60 + began.minute,
        second: began.second,
        utcOffset: began.timeZoneOffset,
        categoryId: category,
        title: strings.practiceTitle,
        // The start and the end, then a line left open: on editing, the
        // cursor stands after it.
        content:
            '${strings.practiceStart}: ${clock(began)}\n\n'
            '${strings.practiceEnd}: '
            '${lastDate == date ? '' : '${strings.gregorian(lastDate)} · '}'
            '${clock(finish)}\n\n'
            '${strings.practiceLog}: ',
        duration: Duration(
          seconds: ended.difference(practice.startedAt).inSeconds,
        ),
      ),
    );
  }

  /// Ends it and writes nothing.
  static void discard() => running.value = null;
}

/// The tally: a count kept by touch, as a hand counter is kept, or the
/// beads of a rosary or a tasbih told. Each touch is one more, felt under
/// the finger; the reset beside it sets it back to nothing. It never goes
/// down by one.
///
/// It is the practice's third way, beside the stopwatch and the countdown
/// (owner, 20 October 2026), and it outlasts the app (main keeps it in
/// the phone's preferences). Written into the journal, as they are, it
/// becomes an entry with the moment and the count, and starts again.
abstract final class PracticeTally {
  static final count = ValueNotifier<int>(0);

  static void add() => count.value++;

  static void reset() => count.value = 0;

  /// Writes the count into [journal] under [categoryId], at this moment,
  /// and starts again. Null if the category is gone.
  static Entry? write(
    JournalStore journal,
    Strings strings,
    String categoryId,
  ) {
    if (journal.category(categoryId) == null) return null;
    final at = PracticeTimer.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final counted = count.value;
    reset();
    return journal.save(
      Entry(
        id: '',
        date: CivilDate(at.year, at.month, at.day),
        minuteOfDay: at.hour * 60 + at.minute,
        second: at.second,
        utcOffset: at.timeZoneOffset,
        categoryId: categoryId,
        title: strings.practiceTally,
        // The moment, the count, then a line left open.
        content:
            '${strings.practiceTime}: '
            '${two(at.hour)}:${two(at.minute)}:${two(at.second)}\n\n'
            '${strings.practiceCounted}: $counted\n\n'
            '${strings.practiceLog}: ',
      ),
    );
  }
}
