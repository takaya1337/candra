import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';

import 'geo.dart';

/// The colours a category can have: twenty-four, one for each category
/// there can be, so no two categories ever share one. Hues run round the
/// wheel in steps of fifteen degrees, alternating a brighter and a deeper
/// tone so that neighbours stay easy to tell apart on a dark background.
final categoryPalette = List<Color>.unmodifiable([
  for (var i = 0; i < 24; i++)
    HSLColor.fromAHSL(
      1,
      i * 15.0,
      i.isEven ? 0.58 : 0.44,
      i.isEven ? 0.63 : 0.54,
    ).toColor(),
]);

/// A user-defined kind of entry. Its colour is the edge of its cards, its
/// dot in the pickers and, later, its dot on the calendar.
class JournalCategory {
  final String id;
  final String name;

  /// Which of the [categoryPalette] colours it has.
  final int colorIndex;

  const JournalCategory({
    required this.id,
    required this.name,
    required this.colorIndex,
  });

  Color get color => categoryPalette[colorIndex];

  JournalCategory copyWith({String? name, int? colorIndex}) => JournalCategory(
    id: id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
  );
}

/// [categories] in the order of their colours round the wheel, so that
/// each sits beside the colours nearest its own.
///
/// The wheel has no beginning, so the row starts after the widest gap
/// between two of them: that way the two colours furthest apart end up at
/// the two ends and never side by side.
List<JournalCategory> byHue(Iterable<JournalCategory> categories) {
  final sorted = categories.toList()
    ..sort((a, b) => a.colorIndex.compareTo(b.colorIndex));
  if (sorted.length < 3) return sorted;
  var start = 0;
  var widest = -1;
  for (var i = 0; i < sorted.length; i++) {
    final previous = sorted[(i - 1) % sorted.length].colorIndex;
    final gap = (sorted[i].colorIndex - previous) % categoryPalette.length;
    if (gap > widest) {
      widest = gap;
      start = i;
    }
  }
  return [...sorted.sublist(start), ...sorted.sublist(0, start)];
}

/// A tag: a name and nothing else, no colour. Finer than a category: an
/// entry or a reminder has one category and any number of tags. Tags are
/// used in the search only, alone or within a category ("category A with
/// tags C and D").
class JournalTag {
  /// Six random hex digits, as a category's: what entries point at, so
  /// the name can change without a file having to move.
  final String id;
  final String name;

  const JournalTag({required this.id, required this.name});

  Map<String, Object> toJson() => {'id': id, 'name': name};

  static JournalTag? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    return JournalTag(id: id, name: name);
  }
}

/// One journal record, anchored to a moment.
///
/// The moment is kept as the local civil date, the time of that day to the
/// second and the UTC offset it was written in, so the day it belongs to
/// never shifts when the device changes timezone.
///
/// No two entries of one day share a second: date and time together name
/// the entry, as its [id] and as its file.
class Entry {
  /// "20261011-193005": the date and the time. Empty until first saved.
  final String id;
  final CivilDate date;
  final int minuteOfDay;

  /// The second within [minuteOfDay].
  final int second;
  final Duration utcOffset;
  final String categoryId;
  final String title;
  final String content;

  /// Where it was written, if it was geotagged.
  final GeoTag? place;

  /// How long what it records went on, if it was timed as a practice;
  /// the entry's own moment is when that began.
  final Duration? duration;

  /// The ids of its tags, in no particular order.
  final List<String> tags;

  /// A bazi chart's inputs, where the entry holds one: written by the bazi
  /// page and read only by it and the chart card, never shown as text
  /// (`BaziRecord`). The content is the user's own.
  final String? bazi;

  /// A cast of the Yijing, where the entry holds one: saved by the I Ching
  /// page and read only by it and the cast's card, never shown as text
  /// (`IchingRecord`). The content is the user's own.
  final String? iching;

  /// The moment it was first saved, as every calendar read it
  /// (`MomentStamp`): written once, kept as it is, never shown. Empty on
  /// an entry made before it was kept.
  final Map<String, String?> moment;

  /// The entry's one unchanging name, from its moment record; null on an
  /// entry made before records were kept. Its [id] follows its date and
  /// time and moves with them; this does not.
  String? get uid => moment['id'];

  const Entry({
    required this.id,
    required this.date,
    required this.minuteOfDay,
    this.second = 0,
    required this.utcOffset,
    required this.categoryId,
    required this.title,
    required this.content,
    this.place,
    this.duration,
    this.tags = const [],
    this.bazi,
    this.iching,
    this.moment = const {},
  });

  /// The id an entry at [secondOfDay] on [date] has.
  static String idFor(CivilDate date, int secondOfDay) =>
      '${_pad(date.year, 4)}${_pad(date.month)}${_pad(date.day)}-'
      '${_pad(secondOfDay ~/ 3600)}${_pad(secondOfDay ~/ 60 % 60)}'
      '${_pad(secondOfDay % 60)}';

  static String _pad(int value, [int width = 2]) =>
      value.toString().padLeft(width, '0');

  int get secondOfDay => minuteOfDay * 60 + second;

  /// [place] replaces the geotag; [untagged] takes it off.
  Entry copyWith({
    String? categoryId,
    String? title,
    String? content,
    GeoTag? place,
    bool untagged = false,
    List<String>? tags,
    String? bazi,
    String? iching,
    Map<String, String?>? moment,
  }) => Entry(
    id: id,
    date: date,
    minuteOfDay: minuteOfDay,
    second: second,
    utcOffset: utcOffset,
    categoryId: categoryId ?? this.categoryId,
    title: title ?? this.title,
    content: content ?? this.content,
    place: untagged ? null : place ?? this.place,
    duration: duration,
    tags: tags ?? this.tags,
    bazi: bazi ?? this.bazi,
    iching: iching ?? this.iching,
    moment: moment ?? this.moment,
  );

  /// Whether [other] is this entry unchanged: every field its file
  /// carries and the app reads back (the moment, the category, the title,
  /// the content, the geotag, the duration, the tags in any order). What is written only for
  /// searching (the calendar lines, the category's name) does not count.
  /// Two entries that differ in any of the rest are two versions, never
  /// one, whatever their title and content say.
  bool sameAs(Entry other) =>
      date == other.date &&
      minuteOfDay == other.minuteOfDay &&
      second == other.second &&
      utcOffset == other.utcOffset &&
      categoryId == other.categoryId &&
      title == other.title &&
      content == other.content &&
      place == other.place &&
      duration == other.duration &&
      bazi == other.bazi &&
      iching == other.iching &&
      tags.length == other.tags.length &&
      tags.toSet().containsAll(other.tags);

  /// The same entry at another second of its day, renamed to match.
  Entry at(int secondOfDay) => Entry(
    id: idFor(date, secondOfDay),
    date: date,
    minuteOfDay: secondOfDay ~/ 60,
    second: secondOfDay % 60,
    utcOffset: utcOffset,
    categoryId: categoryId,
    title: title,
    content: content,
    place: place,
    duration: duration,
    tags: tags,
    bazi: bazi,
    iching: iching,
    moment: moment,
  );

  /// "19:30".
  String get time => '${_pad(minuteOfDay ~/ 60)}:${_pad(minuteOfDay % 60)}';
}

/// One card of the stack: a category and that day's entries in it,
/// earliest first.
class JournalPlane {
  final JournalCategory category;
  final List<Entry> entries;

  const JournalPlane({required this.category, required this.entries});
}

/// Groups a day's [entries] into one plane per category, in the order of
/// [categories]. Entries whose category no longer exists are left out.
List<JournalPlane> planesOf(
  List<Entry> entries,
  List<JournalCategory> categories,
) => [
  for (final category in categories)
    if (entries.any((e) => e.categoryId == category.id))
      JournalPlane(
        category: category,
        entries: entries.where((e) => e.categoryId == category.id).toList()
          ..sort((a, b) => a.secondOfDay.compareTo(b.secondOfDay)),
      ),
];

// Stand-in data until storage exists. Every weekday carries a different
// mix, so each shape of the card stack can be seen by picking a day:
//
//   Monday     2 cards  (2, 1 entries)
//   Tuesday    1 card   (1)
//   Wednesday  4 cards  (1, 3, 1, 2)
//   Thursday   none
//   Friday     2 cards  (1, 1)
//   Saturday   5 cards  (1, 6, 1, 2, 1)
//   Sunday     3 cards  (2, 1, 1)
const _ritual = JournalCategory(id: 'ritual', name: 'Ritual', colorIndex: 2);
const _plant = JournalCategory(id: 'plant', name: 'Plant log', colorIndex: 8);
const _observance = JournalCategory(
  id: 'observance',
  name: 'Observance',
  colorIndex: 14,
);
const _dream = JournalCategory(id: 'dream', name: 'Dream', colorIndex: 18);
const _divination = JournalCategory(
  id: 'divination',
  name: 'Divination',
  colorIndex: 0,
);

/// The categories of the placeholder journal used in tests.
const standInCategories = [_ritual, _plant, _observance, _dream, _divination];

/// The categories a new journal starts with, as name and palette colour.
/// The odd one out comes last.
const startingCategories = [
  ('Occasion', 2),
  ('Observance', 14),
  ('Dream', 18),
  ('Divination', 0),
  ('Plant log', 8),
];

const _texts = <String, List<(int, String, String)>>{
  'ritual': [
    (
      19 * 60 + 30,
      'Evening offering',
      'Three flowers, incense, a bowl of water set facing east. The air '
          'was still until the second stick caught; after that the smoke '
          'leaned north the whole way through.',
    ),
    (
      23 * 60 + 5,
      'Midnight sitting',
      'Forty minutes, back straight, counting breath to nine and '
          'returning. Lost the count twice near the end.',
    ),
  ],
  'plant': [
    (
      6 * 60 + 15,
      'Jasmine by the gate',
      'Two new buds on the lower branch. Watered before sunrise, soil '
          'still damp from the night.',
    ),
    (
      11 * 60 + 40,
      'Basil, east window',
      'Pinched the top pair. The cutting in water has roots a finger '
          'long now.',
    ),
    (
      17 * 60 + 20,
      'Frangipani',
      'First leaf scar of the season. Moved the pot a step out of the '
          'afternoon sun.',
    ),
  ],
  'observance': [
    (
      12 * 60,
      'Fast until dusk',
      'Kept from dawn. Light-headed around noon, clear by late '
          'afternoon. Broke it with water and dates.',
    ),
  ],
  'dream': [
    (
      4 * 60 + 40,
      'The long corridor',
      'Doors on one side only. A lamp at the far end that never got '
          'closer. Woke before reaching it.',
    ),
    (
      5 * 60 + 10,
      'Water under the house',
      'Clear, knee-deep, and warm. Someone upstairs was sweeping.',
    ),
  ],
  'divination': [
    (
      21 * 60 + 15,
      'Three coins, one question',
      'Asked about the move. Changing line in the fourth place. Read it '
          'twice and left it overnight.',
    ),
  ],
};

// For each weekday, Monday first: which categories appear and how many
// entries each has.
const _mixByWeekday = <List<(JournalCategory, int)>>[
  [(_ritual, 2), (_plant, 1)],
  [(_ritual, 1)],
  [(_ritual, 1), (_plant, 3), (_observance, 1), (_dream, 2)],
  [],
  [(_plant, 1), (_dream, 1)],
  [(_ritual, 1), (_plant, 6), (_observance, 1), (_dream, 2), (_divination, 1)],
  [(_ritual, 2), (_plant, 1), (_dream, 1)],
];

/// Placeholder entries for [date].
List<Entry> sampleEntries(CivilDate date, {required Duration utcOffset}) => [
  for (final (category, count) in _mixByWeekday[Weekday.of(date).index])
    for (var i = 0; i < count; i++)
      Entry(
        id: '${date.dayNumber}-${category.id}-$i',
        date: date,
        minuteOfDay: _texts[category.id]![i % _texts[category.id]!.length].$1,
        utcOffset: utcOffset,
        categoryId: category.id,
        title: _texts[category.id]![i % _texts[category.id]!.length].$2,
        content: _texts[category.id]![i % _texts[category.id]!.length].$3,
      ),
];
