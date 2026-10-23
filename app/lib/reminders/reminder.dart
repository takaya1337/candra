import 'package:sacred_time/sacred_time.dart';

/// How a reminder comes round again. Every kind is read off the reminder's
/// first day, so "every weton" needs no weton spelled out: it is the weton
/// of that day.
enum Repeat {
  /// Only on its first day.
  once,
  daily,

  /// Every seven days: the same day of the week.
  weekday,

  /// Every five days: the same pasaran.
  pasaran,

  /// Every thirty-five days: the same weton.
  weton,

  /// The same day number in every Gregorian month.
  gregorianMonth,

  /// The same day and month every Gregorian year.
  gregorianYear,
  javaneseMonth,
  javaneseYear,
  hijriMonth,
  hijriYear,
  chineseMonth,
  chineseYear,

  /// Each time the moon reaches the phase it had on the first day.
  moon,
}

/// What a reminder's time is reckoned from: the clock, or the sun at the
/// place set, worked out again for each day it falls on.
enum SunAnchor {
  clock,

  /// The morning blue hour begins: the sun 6° down, rising.
  morningBlue,
  sunrise,

  /// The evening golden hour begins: the sun 6° up, setting.
  eveningGolden,
  sunset,

  /// The evening blue hour begins: the sun 4° down, setting.
  eveningBlue,

  /// The first hour of the day ruled by [Reminder.planet], counted from
  /// the sun's centre on the horizon (`PlanetaryHours`).
  planetaryHour,
}

/// Something to be reminded of, at a time of day, on a day and then
/// whenever its [repeat] brings it round.
class Reminder {
  final String id;
  final String title;

  /// The first day, which also says what the repeat means.
  final CivilDate start;

  /// The time by the clock; with a [sun] anchor, the last time worked out
  /// (shown where there is no place to work it out from).
  final int minuteOfDay;
  final Repeat repeat;

  /// What the time is reckoned from, and for a sun anchor how many
  /// minutes before it.
  final SunAnchor sun;
  final int lead;

  /// With [SunAnchor.planetaryHour], the planet whose hour it is.
  final Body? planet;

  /// The moment it was first saved, as every calendar read it
  /// (`MomentStamp`): written once, never shown. Empty on one made before
  /// it was kept.
  final Map<String, String?> moment;

  /// Its one unchanging name, from its moment record; null on one made
  /// before records were kept.
  String? get uid => moment['id'];

  /// A reminder switched off is kept but neither shown on the calendar
  /// nor announced.
  final bool enabled;

  /// The journal category it belongs to: the same categories the entries
  /// have. Null on one made before reminders had categories.
  final String? categoryId;

  /// The ids of its tags (the journal's tags), in no particular order.
  final List<String> tags;

  const Reminder({
    required this.id,
    required this.title,
    required this.start,
    required this.minuteOfDay,
    required this.repeat,
    this.enabled = true,
    this.categoryId,
    this.tags = const [],
    this.sun = SunAnchor.clock,
    this.lead = 0,
    this.planet,
    this.moment = const {},
  });

  bool get bySun => sun != SunAnchor.clock;

  /// The minute of [date] it falls at: the clock's; or, by the sun, the
  /// moment at [place] less the lead, null where there is no place or the
  /// sun does not do that that day.
  int? minuteOn(
    CivilDate date, {
    required ({double latitude, double longitude})? place,
    required Duration utcOffset,
  }) {
    if (!bySun) return minuteOfDay;
    if (place == null) return null;
    DateTime? at;
    switch (sun) {
      case SunAnchor.clock:
        break;
      case SunAnchor.planetaryHour:
        // The planet's first hour from sunrise: within the day's twelve,
        // as there are seven planets.
        final hours = PlanetaryHours.of(
          date,
          latitude: place.latitude,
          longitude: place.longitude,
          utcOffset: utcOffset,
        );
        at = hours
            ?.where((h) => h.ruler == (planet ?? Body.sun))
            .firstOrNull
            ?.start;
      case SunAnchor.sunrise:
      case SunAnchor.sunset:
        final day = SkyNow.day(
          Body.sun,
          date,
          latitude: place.latitude,
          longitude: place.longitude,
          utcOffset: utcOffset,
        );
        at = sun == SunAnchor.sunrise ? day.rise : day.set;
      case SunAnchor.morningBlue:
      case SunAnchor.eveningGolden:
      case SunAnchor.eveningBlue:
        at = SkyNow.passing(
          Body.sun,
          date,
          latitude: place.latitude,
          longitude: place.longitude,
          utcOffset: utcOffset,
          altitude: switch (sun) {
            SunAnchor.morningBlue => LightHours.blueBottom,
            SunAnchor.eveningGolden => LightHours.goldenTop,
            _ => LightHours.blueTop,
          },
          rising: sun == SunAnchor.morningBlue,
        );
    }
    if (at == null) return null;
    final midnight = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).subtract(utcOffset);
    final minute = at.difference(midnight).inSeconds / 60 - lead;
    if (minute < 0) return null;
    return minute.floor();
  }

  Reminder copyWith({
    String? id,
    String? title,
    CivilDate? start,
    int? minuteOfDay,
    Repeat? repeat,
    bool? enabled,
    String? categoryId,
    List<String>? tags,
    SunAnchor? sun,
    int? lead,
    Body? planet,
    Map<String, String?>? moment,
  }) => Reminder(
    id: id ?? this.id,
    title: title ?? this.title,
    start: start ?? this.start,
    minuteOfDay: minuteOfDay ?? this.minuteOfDay,
    repeat: repeat ?? this.repeat,
    enabled: enabled ?? this.enabled,
    categoryId: categoryId ?? this.categoryId,
    tags: tags ?? this.tags,
    sun: sun ?? this.sun,
    lead: lead ?? this.lead,
    planet: planet ?? this.planet,
    moment: moment ?? this.moment,
  );

  /// "19:30".
  String get time =>
      '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
      '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

  /// The repeats that make sense for a reminder starting on [start].
  ///
  /// A calendar that cannot place the day is left out, and the moon is
  /// offered only on a day it is new, full or at a quarter: the other
  /// phases last for days and have no one day to be reminded on.
  static List<Repeat> offeredFor(
    CivilDate start, {
    required Duration utcOffset,
  }) => [
    Repeat.once,
    Repeat.daily,
    Repeat.weekday,
    Repeat.pasaran,
    Repeat.weton,
    Repeat.gregorianMonth,
    Repeat.gregorianYear,
    if (JavaneseDate.supports(start)) ...[
      Repeat.javaneseMonth,
      Repeat.javaneseYear,
    ],
    if (HijriDate.supports(start)) ...[Repeat.hijriMonth, Repeat.hijriYear],
    if (ChineseDate.supports(start)) ...[
      Repeat.chineseMonth,
      Repeat.chineseYear,
    ],
    if (Moon.of(start, utcOffset: utcOffset).phase.isPrincipal) Repeat.moon,
  ];

  /// Whether the reminder falls on [date].
  /// [offsetOn], where given, is each date's own offset (the clocks may
  /// change between the first day and [date]); else [utcOffset] for all.
  bool occursOn(
    CivilDate date, {
    required Duration utcOffset,
    Duration Function(CivilDate date)? offsetOn,
  }) {
    final days = date.dayNumber - start.dayNumber;
    if (days < 0) return false;
    if (days == 0) return true;
    switch (repeat) {
      case Repeat.once:
        return false;
      case Repeat.daily:
        return true;
      case Repeat.weekday:
        return days % 7 == 0;
      case Repeat.pasaran:
        return days % 5 == 0;
      case Repeat.weton:
        return days % 35 == 0;
      case Repeat.gregorianMonth:
        return date.day == start.day;
      case Repeat.gregorianYear:
        return date.day == start.day && date.month == start.month;
      case Repeat.javaneseMonth:
      case Repeat.javaneseYear:
        if (!JavaneseDate.supports(date)) return false;
        final a = JavaneseDate.of(start);
        final b = JavaneseDate.of(date);
        return a.day == b.day &&
            (repeat == Repeat.javaneseMonth || a.month == b.month);
      case Repeat.hijriMonth:
      case Repeat.hijriYear:
        final a = HijriDate.of(start);
        final b = HijriDate.of(date);
        return a.day == b.day &&
            (repeat == Repeat.hijriMonth || a.month == b.month);
      case Repeat.chineseMonth:
      case Repeat.chineseYear:
        if (!ChineseDate.supports(date)) return false;
        final a = ChineseDate.of(start);
        final b = ChineseDate.of(date);
        // A yearly day keeps to the ordinary month, not its leap twin.
        return a.day == b.day &&
            (repeat == Repeat.chineseMonth ||
                (a.month == b.month && !b.isLeapMonth));
      case Repeat.moon:
        return Moon.of(
              date,
              utcOffset: offsetOn?.call(date) ?? utcOffset,
            ).phase ==
            Moon.of(start, utcOffset: offsetOn?.call(start) ?? utcOffset).phase;
    }
  }

  /// The days the reminder falls on, from [from] onwards, soonest first:
  /// at most [count] of them, looking no further than [horizon] days.
  List<CivilDate> occurrences(
    CivilDate from, {
    required Duration utcOffset,
    Duration Function(CivilDate date)? offsetOn,
    int count = 1,
    int horizon = 1500,
  }) {
    final found = <CivilDate>[];
    var date = from.dayNumber < start.dayNumber ? start : from;
    for (var i = 0; i < horizon && found.length < count; i++) {
      if (occursOn(date, utcOffset: utcOffset, offsetOn: offsetOn)) {
        found.add(date);
        if (repeat == Repeat.once) break;
      }
      date = date.addDays(1);
    }
    return found;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start':
        '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}',
    'time': time,
    'repeat': repeat.name,
    'enabled': enabled,
    'category': ?categoryId,
    if (tags.isNotEmpty) 'tags': tags,
    if (bySun) 'sun': sun.name,
    if (bySun && lead != 0) 'lead': lead,
    if (sun == SunAnchor.planetaryHour) 'planet': (planet ?? Body.sun).name,
    if (moment.isNotEmpty) 'moment': moment,
  };

  /// Reads back a list of reminders as kept in `reminders.json`, one by
  /// one: whatever is not a reminder is left out and the rest are kept.
  /// Throws only if [json] is not a list at all.
  static List<Reminder> listFrom(Object? json) => [
    for (final item in json as List)
      if (item is Map<String, dynamic>) ?Reminder.fromJson(item),
  ];

  /// Reads a reminder back, or returns null if [json] is not one.
  static Reminder? fromJson(Map<String, dynamic> json) {
    final date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
        .firstMatch('${json['start']}');
    final time = RegExp(r'^(\d{2}):(\d{2})$').firstMatch('${json['time']}');
    final repeat = Repeat.values
        .where((r) => r.name == json['repeat'])
        .firstOrNull;
    final id = json['id'];
    if (date == null || time == null || repeat == null || id is! String) {
      return null;
    }
    // A date of the right shape can still be no day at all (the 30th of
    // February). That makes this one not a reminder, rather than an error
    // for the whole list.
    try {
      return _fromJson(json, id, date, time, repeat);
    } on Error {
      return null;
    }
  }

  static Reminder _fromJson(
    Map<String, dynamic> json,
    String id,
    RegExpMatch date,
    RegExpMatch time,
    Repeat repeat,
  ) {
    return Reminder(
      id: id,
      title: '${json['title'] ?? ''}',
      start: CivilDate(
        int.parse(date[1]!),
        int.parse(date[2]!),
        int.parse(date[3]!),
      ),
      minuteOfDay: int.parse(time[1]!) * 60 + int.parse(time[2]!),
      repeat: repeat,
      enabled: json['enabled'] != false,
      categoryId: json['category'] is String ? json['category'] : null,
      tags: [
        if (json['tags'] case final List list)
          for (final id in list)
            if (id is String) id,
      ],
      sun:
          SunAnchor.values.where((a) => a.name == json['sun']).firstOrNull ??
          SunAnchor.clock,
      lead: json['lead'] is int ? json['lead'] as int : 0,
      planet: Body.values.where((b) => b.name == json['planet']).firstOrNull,
      moment: {
        if (json['moment'] case final Map map)
          for (final MapEntry(:key, :value) in map.entries)
            if (key is String && (value == null || value is String))
              key: value as String?,
      },
    );
  }
}
