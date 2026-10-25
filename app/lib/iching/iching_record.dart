import 'package:sacred_time/sacred_time.dart';

/// The three ways of casting: the coins, the stalks, and by hand (the
/// six lines set one by one by the user, as cast elsewhere).
enum CastMethod { coins, stalks, manual }

/// A cast of the Yijing as it is kept with the journal entry it is saved
/// to (`Entry.iching`, an `iching:` line among the entry file's metadata),
/// so the hexagram can be drawn and read back exactly, and never shown as
/// text:
///
///     v1 method=coins lines=789678 date=2026-10-24 time=19:05 offset=+07:00
///
/// The lines from the bottom up, each the number it was cast as (6, 7, 8
/// or 9); the date, time and offset are the moment it was cast, by the
/// phone's clock. The same in every language. Only the user's own saving
/// of a cast puts it in the journal; the screen keeps nothing by itself.
class IchingRecord {
  final CastMethod method;

  /// The six lines, from the bottom up.
  final List<LineValue> lines;
  final CivilDate date;
  final int minute;
  final Duration offset;

  const IchingRecord({
    required this.method,
    required this.lines,
    required this.date,
    required this.minute,
    required this.offset,
  });

  static const _mark = 'v1';

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _offset(Duration d) {
    final m = d.inMinutes;
    return '${m < 0 ? '-' : '+'}${_two(m.abs() ~/ 60)}:${_two(m.abs() % 60)}';
  }

  YijingCast get cast => YijingCast(lines);

  String get value =>
      '$_mark '
      'method=${method.name} '
      'lines=${lines.map((line) => line.number).join()} '
      'date=${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)} '
      'time=${_two(minute ~/ 60)}:${_two(minute % 60)} '
      'offset=${_offset(offset)}';

  /// The record [value] holds, or null where there is none, or it lacks
  /// anything, or holds what cannot be: a cast is only read back whole.
  static IchingRecord? parse(String? value) {
    final text = value?.trim() ?? '';
    if (!text.startsWith('$_mark ')) return null;
    final fields = <String, String>{
      for (final part
          in text.substring(_mark.length + 1).trim().split(RegExp(r'\s+')))
        if (part.contains('='))
          part.substring(0, part.indexOf('=')): part.substring(
            part.indexOf('=') + 1,
          ),
    };
    final method = CastMethod.values
        .where((m) => m.name == fields['method'])
        .firstOrNull;
    final lines = RegExp(r'^[6789]{6}$').firstMatch(fields['lines'] ?? '');
    final date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
        .firstMatch(fields['date'] ?? '');
    final time = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(fields['time'] ?? '');
    final offset = RegExp(r'^([+-])(\d{2}):(\d{2})$')
        .firstMatch(fields['offset'] ?? '');
    if (method == null ||
        lines == null ||
        date == null ||
        time == null ||
        offset == null) {
      return null;
    }
    final y = int.parse(date[1]!), mo = int.parse(date[2]!);
    final d = int.parse(date[3]!);
    final h = int.parse(time[1]!), mi = int.parse(time[2]!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) {
      return null;
    }
    // A day that does not exist (31 February) is refused.
    final CivilDate civil;
    try {
      civil = CivilDate(y, mo, d);
    } on ArgumentError {
      return null;
    }
    final minutes =
        (int.parse(offset[2]!) * 60 + int.parse(offset[3]!)) *
        (offset[1] == '-' ? -1 : 1);
    if (minutes.abs() > 14 * 60) return null;
    return IchingRecord(
      method: method,
      lines: [
        for (final digit in lines[0]!.split('')) LineValue.of(int.parse(digit)),
      ],
      date: civil,
      minute: h * 60 + mi,
      offset: Duration(minutes: minutes),
    );
  }
}
