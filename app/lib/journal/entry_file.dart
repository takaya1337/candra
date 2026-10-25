import 'package:sacred_time/sacred_time.dart';

import '../strings.dart';
import 'entry.dart';
import 'geo.dart';

/// An entry as a Markdown file: a block of `key: value` lines between two
/// `---` lines, then the content, untouched.
///
/// The first lines of the block are the entry itself, with where it was
/// written if it was geotagged. The rest describe
/// its day as every calendar reads it, in one fixed wording, so that a
/// plain text search over the files finds every entry of a weton, a
/// Javanese month or a moon phase without working anything out. The
/// wording is English wherever an English word exists (weekdays, the
/// zodiac, moon phases), whatever language the app is in; a word that has
/// none (pasaran, neptu, the Javanese months) stays as it is. The app
/// writes those lines and never reads them back: the date is the truth,
/// and they are worked out from it again on every save.
abstract final class EntryFile {
  static const _fence = '---';

  // The app's own English wording, so files and screen agree.
  static const _words = Strings(AppLanguage.en);

  // In the order of [Weekday].
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Where an entry's file sits below the entries folder:
  /// `2026/10/11/3fa9c1/193005.md`, the folder being the category's id
  /// (six random hex digits), never its name.
  static String pathOf(Entry entry) =>
      '${dayPath(entry.date)}/${entry.categoryId}/'
      '${_pad(entry.minuteOfDay ~/ 60)}${_pad(entry.minuteOfDay % 60)}'
      '${_pad(entry.second)}.md';

  /// `2026/10/11`.
  static String dayPath(CivilDate date) =>
      '${_pad(date.year, 4)}/${_pad(date.month)}/${_pad(date.day)}';

  static String encode(
    Entry entry, {
    required String categoryName,
    List<String> tagNames = const [],
  }) {
    final date = entry.date;
    final weton = Weton.of(date);
    final moon = Moon.of(date, utcOffset: entry.utcOffset);
    final lines = <String>[
      _fence,
      'id: ${entry.id}',
      'date: ${_pad(date.year, 4)}-${_pad(date.month)}-${_pad(date.day)}',
      'time: ${entry.time}:${_pad(entry.second)}',
      'utc_offset: ${_offset(entry.utcOffset)}',
      'category: ${entry.categoryId}',
      'category_name: ${_oneLine(categoryName)}',
      'title: ${_oneLine(entry.title)}',
      if (entry.tags.isNotEmpty) ...[
        'tags: ${entry.tags.join(', ')}',
        if (tagNames.isNotEmpty)
          'tag_names: ${tagNames.map(_oneLine).join(' · ')}',
      ],
      if (entry.duration case final duration?) ...[
        '# How long it went on, timed as a practice: hours, minutes, seconds.',
        'duration: ${_pad(duration.inHours)}:'
            '${_pad(duration.inMinutes % 60)}:${_pad(duration.inSeconds % 60)}',
      ],
      if (entry.bazi case final bazi?) ...[
        '# A bazi chart: what it is read from. The app draws the chart from',
        '# this line; the text below is the writer\'s own.',
        'bazi: ${_oneLine(bazi)}',
      ],
      if (entry.iching case final iching?) ...[
        '# A cast of the I Ching: its lines from the bottom up, and when it',
        '# was cast. The app draws the hexagram from this line; the text',
        '# below is the writer\'s own.',
        'iching: ${_oneLine(iching)}',
      ],
      if (entry.place case final place?) ...[
        '# Where it was written, rounded to about 100 m: not the exact spot.',
        'latitude: ${place.latitude.toStringAsFixed(GeoTag.decimals)}',
        'longitude: ${place.longitude.toStringAsFixed(GeoTag.decimals)}',
        if (place.name.isNotEmpty) 'place: ${place.name}',
      ],
      if (entry.moment.isNotEmpty) ...[
        '# The moment it was first saved, as every calendar read it. Kept',
        '# as written, never worked out again; the app does not show it.',
        for (final MapEntry(:key, :value) in entry.moment.entries)
          'moment_$key: ${value == null ? 'null' : _oneLine(value)}',
      ],
      '# The day as every calendar reads it. Written for searching; the app',
      '# works these out from the date and ignores them when reading.',
      'weekday: ${_weekdays[weton.weekday.index]}',
      'pasaran: ${weton.pasaran.label}',
      'weton: ${_weekdays[weton.weekday.index]} ${weton.pasaran.label}',
      'neptu: ${weton.neptu}',
    ];
    if (JavaneseDate.supports(date)) {
      final javanese = JavaneseDate.of(date);
      lines.addAll([
        'javanese: ${javanese.day} ${javanese.month.label} '
            '${javanese.year} ${javanese.taun.label}',
        'javanese_day: ${javanese.day}',
        'javanese_month: ${javanese.month.label}',
        'javanese_year: ${javanese.year}',
        'javanese_taun: ${javanese.taun.label}',
      ]);
    }
    if (ChineseDate.supports(date)) {
      final chinese = ChineseDate.of(date);
      lines.addAll([
        'chinese: ${_words.chinese(chinese)} ${_words.zodiac(chinese)}',
        'chinese_day: ${chinese.day}',
        'chinese_month: ${chinese.month}',
        'chinese_leap_month: ${chinese.isLeapMonth}',
        'chinese_year: ${chinese.kongziliYear}',
        'chinese_zodiac: ${_words.zodiacAnimal(chinese)}',
        'chinese_element: ${_words.zodiacElement(chinese)}',
        'chinese_day_element: ${_words.dayElement(date)}',
      ]);
    }
    if (HijriDate.supports(date)) {
      final hijri = HijriDate.of(date);
      lines.addAll([
        'hijri: ${hijri.day} ${_words.hijriMonth(hijri.month)} ${hijri.year}',
        'hijri_day: ${hijri.day}',
        'hijri_month: ${_words.hijriMonth(hijri.month)}',
        'hijri_year: ${hijri.year}',
      ]);
    }
    lines.addAll([
      'moon_phase: ${moon.phase.label}',
      'moon_illumination: ${(moon.illumination * 100).round()}',
      _fence,
    ]);
    return '${lines.join('\n')}\n${entry.content}\n';
  }

  /// Reads an entry back, or returns null if [text] is not one.
  static Entry? decode(String text) {
    final lines = text.split('\n');
    if (lines.isEmpty || lines.first.trim() != _fence) return null;
    final end = lines.indexWhere((line) => line.trim() == _fence, 1);
    if (end < 0) return null;

    final fields = <String, String>{};
    for (final line in lines.sublist(1, end)) {
      final colon = line.indexOf(':');
      if (line.startsWith('#') || colon < 0) continue;
      fields[line.substring(0, colon).trim()] = line
          .substring(colon + 1)
          .trim();
    }

    final date = _date(fields['date']);
    final time = _time(fields['time']);
    final offset = _parseOffset(fields['utc_offset']);
    final category = fields['category'];
    if (date == null || time == null || offset == null || category == null) {
      return null;
    }

    var content = lines.sublist(end + 1).join('\n');
    if (content.endsWith('\n')) {
      content = content.substring(0, content.length - 1);
    }
    return Entry(
      id: Entry.idFor(date, time),
      date: date,
      minuteOfDay: time ~/ 60,
      second: time % 60,
      utcOffset: offset,
      categoryId: category,
      title: fields['title'] ?? '',
      content: content,
      // Rounded on the way in too, should a file hold more than is kept.
      place: GeoTag.rounded(
        double.tryParse(fields['latitude'] ?? '') ?? double.nan,
        double.tryParse(fields['longitude'] ?? '') ?? double.nan,
        name: fields['place'] ?? '',
      ),
      duration: _duration(fields['duration']),
      tags: [
        for (final id in (fields['tags'] ?? '').split(','))
          if (id.trim().isNotEmpty) id.trim(),
      ],
      bazi: fields['bazi'],
      iching: fields['iching'],
      moment: {
        for (final MapEntry(:key, :value) in fields.entries)
          if (key.startsWith('moment_'))
            key.substring(7): value == 'null' ? null : value,
      },
    );
  }

  static String _pad(int value, [int width = 2]) =>
      value.toString().padLeft(width, '0');

  static String _oneLine(String text) =>
      text.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();

  /// "+07:00".
  static String _offset(Duration offset) {
    final minutes = offset.inMinutes.abs();
    return '${offset.isNegative ? '-' : '+'}'
        '${_pad(minutes ~/ 60)}:${_pad(minutes % 60)}';
  }

  static Duration? _parseOffset(String? text) {
    final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(text ?? '');
    if (match == null) return null;
    final minutes = int.parse(match[2]!) * 60 + int.parse(match[3]!);
    return Duration(minutes: match[1] == '-' ? -minutes : minutes);
  }

  static CivilDate? _date(String? text) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text ?? '');
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    // A file edited by hand can name a day that does not exist, such as
    // 2026-02-30. That makes it not an entry, rather than an error that
    // would stop the rest of the journal being read.
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > CivilDate.daysInMonth(year, month)) {
      return null;
    }
    return CivilDate(year, month, day);
  }

  static Duration? _duration(String? text) {
    final match = RegExp(r'^(\d+):(\d{2}):(\d{2})$').firstMatch(text ?? '');
    if (match == null) return null;
    return Duration(
      hours: int.parse(match[1]!),
      minutes: int.parse(match[2]!),
      seconds: int.parse(match[3]!),
    );
  }

  /// The second of the day.
  static int? _time(String? text) {
    final match = RegExp(r'^(\d{2}):(\d{2})(?::(\d{2}))?$')
        .firstMatch(text ?? '');
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    final second = int.parse(match[3] ?? '0');
    // Likewise a time that is not one, such as 25:00, would name a second
    // outside the day.
    if (hour > 23 || minute > 59 || second > 59) return null;
    return hour * 3600 + minute * 60 + second;
  }
}
