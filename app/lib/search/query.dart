import 'package:sacred_time/sacred_time.dart';

import '../journal/entry.dart';
import '../journal/journal_store.dart';
import '../reminders/reminder.dart';
import '../reminders/reminder_store.dart';
import '../strings.dart';

/// A cycle of the calendars that a day can be searched by. Each reads a
/// day as one of its values (Kliwon is the fifth of the pasaran); a day it
/// cannot read, outside its calendar's range, has none and is never found.
enum CycleKind {
  weekday(7),
  pasaran(5),
  weton(35),
  moon(8),
  javaneseMonth(12),
  javaneseDay(30),
  hijriMonth(12),
  hijriDay(30),
  chineseMonth(12),
  chineseDay(30),
  mangsa(12),
  dayElement(10),

  /// The planet whose hour holds the moment: not a day's, an hour's, so
  /// it narrows entries and reminders by their time and never the days.
  planetaryHour(7);

  /// How many values the cycle has.
  final int count;

  const CycleKind(this.count);

  /// The planets in the order of the week's days, from Sunday's: the
  /// values of [planetaryHour].
  static const planets = [
    Body.sun,
    Body.moon,
    Body.mars,
    Body.mercury,
    Body.jupiter,
    Body.venus,
    Body.saturn,
  ];

  /// Whether the cycle is of a moment, not of a day.
  bool get ofTheHour => this == planetaryHour;

  /// The value of the moment [minute] into [date] at [place]: the
  /// planetary hour's planet, null with no place or no hours there.
  static int? planetAt(
    CivilDate date,
    int minute, {
    required Duration Function(CivilDate date) offsetOn,
    required ({double latitude, double longitude})? place,
  }) {
    if (place == null) return null;
    final instant = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: minute)).subtract(offsetOn(date));
    final hour = PlanetaryHours.at(
      instant,
      latitude: place.latitude,
      longitude: place.longitude,
      offsetOn: offsetOn,
    );
    return hour == null ? null : planets.indexOf(hour.ruler);
  }

  /// The value [date] has in this cycle, or null where it has none (and
  /// always null for a cycle of the hour: see [planetAt]).
  int? valueOf(CivilDate date, {required Duration utcOffset}) {
    switch (this) {
      case weekday:
        return Weekday.of(date).index;
      case pasaran:
        return Pasaran.of(date).index;
      case weton:
        final w = Weton.of(date);
        return w.weekday.index * 5 + w.pasaran.index;
      case moon:
        return Moon.of(date, utcOffset: utcOffset).phase.index;
      case javaneseMonth:
        return JavaneseDate.supports(date)
            ? JavaneseDate.of(date).month.index
            : null;
      case javaneseDay:
        return JavaneseDate.supports(date)
            ? JavaneseDate.of(date).day - 1
            : null;
      case hijriMonth:
        return HijriDate.supports(date) ? HijriDate.of(date).month.index : null;
      case hijriDay:
        return HijriDate.supports(date) ? HijriDate.of(date).day - 1 : null;
      case chineseMonth:
        return ChineseDate.supports(date)
            ? ChineseDate.of(date).month - 1
            : null;
      case chineseDay:
        return ChineseDate.supports(date) ? ChineseDate.of(date).day - 1 : null;
      case mangsa:
        return PranataMangsa.supports(date)
            ? PranataMangsa.of(date).mangsa.index
            : null;
      case dayElement:
        return (date.dayNumber + 49) % 10;
      case planetaryHour:
        return null;
    }
  }

  /// What value [value] is called.
  String label(int value, Strings strings) {
    switch (this) {
      case weekday:
        return strings.weekdayName(Weekday.values[value]);
      case pasaran:
        return Pasaran.values[value].label;
      case weton:
        return '${Weekday.values[value ~/ 5].label} '
            '${Pasaran.values[value % 5].label}';
      case moon:
        return strings.moonPhase(MoonPhase.values[value]);
      case javaneseMonth:
        return JavaneseMonth.values[value].label;
      case hijriMonth:
        return strings.hijriMonth(HijriMonth.values[value]);
      case chineseMonth:
        return strings.chineseMonth(_chineseMonths[value]);
      case javaneseDay:
      case hijriDay:
      case chineseDay:
        return '${value + 1}';
      case mangsa:
        return Mangsa.values[value].label;
      case dayElement:
        // A day whose stem is [value]: the cycle of ten, from 2451545.
        final base = 2451545 + (value - (2451545 + 49) % 10) % 10;
        return strings.dayElement(CivilDate.fromDayNumber(base));
      case planetaryHour:
        return strings.planetName(planets[value]);
    }
  }

  // A day of each Chinese month (not a leap one), for its name.
  static final List<ChineseDate> _chineseMonths = () {
    final found = <int, ChineseDate>{};
    for (var d = CivilDate(2026, 1, 1); found.length < 12; d = d.addDays(15)) {
      final chinese = ChineseDate.of(d);
      if (!chinese.isLeapMonth) found.putIfAbsent(chinese.month, () => chinese);
    }
    return [for (var m = 1; m <= 12; m++) found[m]!];
  }();
}

/// When a day turns, for the search: at midnight, as the calendar has it;
/// at sunset, as Javanese and Islamic reckoning has it (Thursday evening
/// is already malam Jumat); or at six in the evening, sunset's usual hour
/// in Java, for when no place is set.
enum Evening { midnight, sunset, six }

/// What is searched for. Categories are alternatives (any of them); tags
/// are all required (every one of them); cycles of different kinds are
/// all required, and values within one kind are alternatives (Kliwon or
/// Legi). Words are all required, in the title or the content.
class SearchQuery {
  final bool entries;
  final bool reminders;
  final Set<String> categories;
  final Set<String> tags;
  final Map<CycleKind, Set<int>> cycles;
  final Evening evening;
  final String words;

  /// Count each by when it was first saved, from its moment record, not
  /// by the day it is about (owner, 17 October 2026). One without a
  /// record is then never found by a cycle.
  final bool byMoment;

  const SearchQuery({
    this.entries = true,
    this.reminders = false,
    this.categories = const {},
    this.tags = const {},
    this.cycles = const {},
    this.evening = Evening.midnight,
    this.words = '',
    this.byMoment = false,
  });

  SearchQuery copyWith({
    bool? entries,
    bool? reminders,
    Set<String>? categories,
    Set<String>? tags,
    Map<CycleKind, Set<int>>? cycles,
    Evening? evening,
    String? words,
    bool? byMoment,
  }) => SearchQuery(
    entries: entries ?? this.entries,
    reminders: reminders ?? this.reminders,
    categories: categories ?? this.categories,
    tags: tags ?? this.tags,
    cycles: cycles ?? this.cycles,
    evening: evening ?? this.evening,
    words: words ?? this.words,
    byMoment: byMoment ?? this.byMoment,
  );

  /// The query with value [value] of [kind] added, or taken off if it was
  /// there.
  SearchQuery toggleCycle(CycleKind kind, int value) {
    final next = {
      for (final e in cycles.entries) e.key: {...e.value},
    };
    final values = next.putIfAbsent(kind, () => {});
    if (!values.remove(value)) values.add(value);
    if (values.isEmpty) next.remove(kind);
    return copyWith(cycles: next);
  }

  bool get hasCycles => cycles.isNotEmpty;

  /// Whether nothing narrows it: everything in what is looked in is found.
  bool get isOpen =>
      categories.isEmpty && tags.isEmpty && cycles.isEmpty && _words.isEmpty;

  List<String> get _words => [
    for (final w in words.toLowerCase().split(RegExp(r'\s+')))
      if (w.isNotEmpty) w,
  ];

  /// Whether [day] has every cycle asked for. A cycle of the hour is
  /// asked of the moment [minute] into [date] (its own day, not the one
  /// it is reckoned as) at [place]; with no moment, every day has every
  /// hour, and it does not narrow the days.
  bool dayMatches(
    CivilDate day, {
    required Duration utcOffset,
    CivilDate? date,
    int? minute,
    ({double latitude, double longitude})? place,
    Duration Function(CivilDate date)? offsetOn,
    int? Function()? planet,
  }) {
    for (final MapEntry(key: kind, value: values) in cycles.entries) {
      if (kind.ofTheHour) {
        // As recorded, where the moment's record says it.
        if (planet != null) {
          final value = planet();
          if (value == null || !values.contains(value)) return false;
          continue;
        }
        if (minute == null) continue;
        final value = CycleKind.planetAt(
          date ?? day,
          minute,
          offsetOn: offsetOn ?? (_) => utcOffset,
          place: place,
        );
        if (value == null || !values.contains(value)) return false;
        continue;
      }
      final value = kind.valueOf(day, utcOffset: utcOffset);
      if (value == null || !values.contains(value)) return false;
    }
    return true;
  }

  bool get _byHour => cycles.keys.any((k) => k.ofTheHour);

  /// When a moment record says it was first saved, by its own clock;
  /// null where it has none.
  static ({CivilDate date, int minute, Duration offset})? momentOf(
    Map<String, String?> moment,
  ) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):\d{2} ([+-])(\d{2}):(\d{2})$',
    ).firstMatch(moment['local'] ?? '');
    if (match == null) return null;
    final offset = Duration(
      minutes:
          (int.parse(match[7]!) * 60 + int.parse(match[8]!)) *
          (match[6] == '-' ? -1 : 1),
    );
    return (
      date: CivilDate(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      ),
      minute: int.parse(match[4]!) * 60 + int.parse(match[5]!),
      offset: offset,
    );
  }

  /// The planetary hour's planet as a moment record has it ("Mercury,
  /// day hour 3"): a value of [CycleKind.planetaryHour], or null.
  static int? recordedPlanet(Map<String, String?> moment) {
    final hour = moment['planetary_hour'];
    if (hour == null) return null;
    const english = Strings(AppLanguage.en);
    for (final (i, body) in CycleKind.planets.indexed) {
      if (hour.startsWith('${english.planetName(body)},')) return i;
    }
    return null;
  }

  // Whether a moment record fits the cycles: its own day under the
  // evening rule, its recorded planetary hour.
  bool _momentFits(
    Map<String, String?> moment,
    int? Function(CivilDate date)? sunset,
  ) {
    final at = momentOf(moment);
    if (at == null) return false;
    return dayMatches(
      reckoned(at.date, at.minute, sunset: sunset),
      utcOffset: at.offset,
      planet: () => recordedPlanet(moment),
    );
  }

  /// The day a moment belongs to under [evening]: its own date, or the
  /// next once the evening has begun. [sunset] says, in minutes after
  /// midnight, when the sun sets on a date; null where it does not.
  CivilDate reckoned(
    CivilDate date,
    int minuteOfDay, {
    int? Function(CivilDate date)? sunset,
  }) {
    final turn = switch (evening) {
      Evening.midnight => null,
      Evening.six => 18 * 60,
      Evening.sunset => sunset?.call(date),
    };
    return turn != null && minuteOfDay >= turn ? date.addDays(1) : date;
  }

  bool _fits(String? categoryId, List<String> tagsHere, String text) {
    if (categories.isNotEmpty && !categories.contains(categoryId)) {
      return false;
    }
    if (!tagsHere.toSet().containsAll(tags)) return false;
    final lower = text.toLowerCase();
    return _words.every(lower.contains);
  }

  /// The entries found, newest first.
  List<SearchHit> searchEntries(
    JournalStore store, {
    int? Function(CivilDate date)? sunset,
    ({double latitude, double longitude})? place,
  }) {
    if (!entries) return const [];
    final days = <int, bool>{};
    final found = <SearchHit>[];
    for (final entry in store.allEntries()) {
      if (!_fits(
        entry.categoryId,
        entry.tags,
        '${entry.title}\n${entry.content}',
      )) {
        continue;
      }
      final day = reckoned(entry.date, entry.minuteOfDay, sunset: sunset);
      if (hasCycles && byMoment) {
        if (!_momentFits(entry.moment, sunset)) continue;
        found.add(SearchHit.entry(entry, day));
        continue;
      }
      if (hasCycles &&
          !(_byHour
              // By the hour, each entry at its own moment, where it was
              // written if it says, else at the place set.
              ? dayMatches(
                  day,
                  utcOffset: entry.utcOffset,
                  date: entry.date,
                  minute: entry.minuteOfDay,
                  place: entry.place == null
                      ? place
                      : (
                          latitude: entry.place!.latitude,
                          longitude: entry.place!.longitude,
                        ),
                )
              : days.putIfAbsent(
                  day.dayNumber,
                  () => dayMatches(day, utcOffset: entry.utcOffset),
                ))) {
        continue;
      }
      found.add(SearchHit.entry(entry, day));
    }
    found.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return found;
  }

  /// The reminders found, each once, at the first of its coming days (from
  /// [from]) that fits: soonest first. Switched off ones are not found.
  List<SearchHit> searchReminders(
    ReminderStore store, {
    required CivilDate from,
    int? Function(CivilDate date)? sunset,
  }) {
    if (!reminders) return const [];
    final found = <SearchHit>[];
    for (final reminder in store.reminders) {
      if (!reminder.enabled) continue;
      if (!_fits(reminder.categoryId, reminder.tags, reminder.title)) continue;
      // By when it was set: found, if it fits, at its next day.
      if (hasCycles && byMoment) {
        if (!_momentFits(reminder.moment, sunset)) continue;
        final next = reminder
            .occurrences(
              from,
              utcOffset: store.utcOffset,
              offsetOn: store.offsetOn,
            )
            .firstOrNull;
        if (next != null) found.add(SearchHit.reminder(reminder, next, next));
        continue;
      }
      for (final date in reminder.occurrences(
        from,
        utcOffset: store.utcOffset,
        offsetOn: store.offsetOn,
        // With cycles, every coming day up to the usual horizon, to find
        // the first that fits.
        count: hasCycles ? 1500 : 1,
      )) {
        // A reminder by the sun at that day's own time.
        final minute = store.minuteOf(reminder, date);
        final day = reckoned(date, minute, sunset: sunset);
        if (dayMatches(
          day,
          utcOffset: store.offsetOn(day),
          date: date,
          minute: minute,
          place: store.placeOf(),
          offsetOn: store.offsetOn,
        )) {
          found.add(SearchHit.reminder(reminder, date, day));
          break;
        }
      }
    }
    found.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return found;
  }

  /// The reminders that fit on [date] itself: for the month and the year.
  List<Reminder> remindersOn(
    ReminderStore store,
    CivilDate date, {
    int? Function(CivilDate date)? sunset,
  }) {
    if (!reminders) return const [];
    return [
      for (final reminder in store.on(date))
        if (_fits(reminder.categoryId, reminder.tags, reminder.title) &&
            (byMoment && hasCycles
                ? _momentFits(reminder.moment, sunset)
                : dayMatches(
                    reckoned(
                      date,
                      store.minuteOf(reminder, date),
                      sunset: sunset,
                    ),
                    utcOffset: store.offsetOn(date),
                    date: date,
                    minute: store.minuteOf(reminder, date),
                    place: store.placeOf(),
                    offsetOn: store.offsetOn,
                  )))
          reminder,
    ];
  }
}

/// Something found: an entry, or a reminder on one of its days. [date] is
/// its own date; [day] the day it was reckoned as, which under an evening
/// rule may be the next.
class SearchHit {
  final Entry? entry;
  final Reminder? reminder;
  final CivilDate date;
  final CivilDate day;

  SearchHit.entry(Entry this.entry, this.day)
    : reminder = null,
      date = entry.date;

  const SearchHit.reminder(Reminder this.reminder, this.date, this.day)
    : entry = null;

  int get minuteOfDay => entry?.minuteOfDay ?? reminder!.minuteOfDay;

  int get sortKey =>
      date.dayNumber * 86400 + (entry?.secondOfDay ?? minuteOfDay * 60);
}
