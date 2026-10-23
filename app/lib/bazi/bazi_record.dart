import 'package:sacred_time/sacred_time.dart';

/// What a bazi chart is read from, kept with the journal entry it is
/// written to (`Entry.bazi`, a `bazi:` line among the entry file's
/// metadata), so the chart can be drawn and read back exactly, and never
/// shown as text:
///
///     v1 date=2026-10-16 time=07:00 offset=+07:00 zone=Asia/Jakarta
///     lon=106.6 sex=m time-mode=trueSolar zi=split year=lichun
///     luck=3:termInstant:exact hidden=ziping.v1 relations=ziping.v1
///
/// (on one line), the same in every language. `-` where there is no
/// zone, longitude or sex. Only the user's own writing of a chart puts it
/// in the journal; the screen keeps nothing by itself.
class BaziRecord {
  final CivilDate date;
  final int minute;
  final Duration offset;
  final String? zone;
  final double? longitude;
  final bool? male;
  final BaziConfig config;
  final String hidden;
  final String relations;

  const BaziRecord({
    required this.date,
    required this.minute,
    required this.offset,
    required this.zone,
    required this.longitude,
    required this.male,
    required this.config,
    required this.hidden,
    required this.relations,
  });

  static const _mark = 'v1';

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _offset(Duration d) {
    final m = d.inMinutes;
    return '${m < 0 ? '-' : '+'}${_two(m.abs() ~/ 60)}:${_two(m.abs() % 60)}';
  }

  String get value {
    final c = config;
    final luckDivisor = c.luckDivisor == c.luckDivisor.roundToDouble()
        ? c.luckDivisor.toInt().toString()
        : c.luckDivisor.toString();
    return '$_mark '
        'date=${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)} '
        'time=${_two(minute ~/ 60)}:${_two(minute % 60)} '
        'offset=${_offset(offset)} '
        'zone=${zone ?? '-'} '
        'lon=${longitude?.toStringAsFixed(1) ?? '-'} '
        'sex=${male == null ? '-' : (male! ? 'm' : 'f')} '
        'time-mode=${c.timeMode.name} '
        'zi=${c.ziHourRule.name} '
        'year=${c.yearBoundary.name} '
        'luck=$luckDivisor:${c.luckAnchor.name}:${c.luckRounding.name} '
        'hidden=$hidden '
        'relations=$relations';
  }

  /// The record [value] holds, or null where there is none, or it lacks
  /// anything the chart needs, or holds what cannot be: a chart is only
  /// read back whole.
  static BaziRecord? parse(String? value) {
    final text = value?.trim() ?? '';
    if (!text.startsWith('$_mark ')) return null;
    final line = text.substring(_mark.length + 1);
    final fields = <String, String>{
      for (final part in line.trim().split(RegExp(r'\s+')))
        if (part.contains('='))
          part.substring(0, part.indexOf('=')): part.substring(
            part.indexOf('=') + 1,
          ),
    };
    T? named<T extends Enum>(List<T> values, String? name) =>
        values.where((v) => v.name == name).firstOrNull;

    final date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
        .firstMatch(fields['date'] ?? '');
    final time = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(fields['time'] ?? '');
    final offset = RegExp(r'^([+-])(\d{2}):(\d{2})$')
        .firstMatch(fields['offset'] ?? '');
    final luck = (fields['luck'] ?? '').split(':');
    final timeMode = named(TimeMode.values, fields['time-mode']);
    final zi = named(ZiHourRule.values, fields['zi']);
    final year = named(YearBoundary.values, fields['year']);
    final anchor = luck.length == 3 ? named(LuckAnchor.values, luck[1]) : null;
    final rounding = luck.length == 3
        ? named(LuckRounding.values, luck[2])
        : null;
    final divisor = luck.isEmpty ? null : double.tryParse(luck[0]);
    final zone = fields['zone'];
    final lon = fields['lon'];
    final sex = fields['sex'];
    final hidden = fields['hidden'];
    final relations = fields['relations'];
    if (date == null ||
        time == null ||
        offset == null ||
        timeMode == null ||
        zi == null ||
        year == null ||
        anchor == null ||
        rounding == null ||
        divisor == null ||
        divisor <= 0 ||
        zone == null ||
        lon == null ||
        sex == null ||
        hidden == null ||
        relations == null) {
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
    final longitude = lon == '-' ? null : double.tryParse(lon);
    if (lon != '-' && (longitude == null || longitude.abs() > 180)) {
      return null;
    }
    if (!const {'m', 'f', '-'}.contains(sex)) return null;
    final minutes =
        (int.parse(offset[2]!) * 60 + int.parse(offset[3]!)) *
        (offset[1] == '-' ? -1 : 1);
    if (minutes.abs() > 14 * 60) return null;
    return BaziRecord(
      date: civil,
      minute: h * 60 + mi,
      offset: Duration(minutes: minutes),
      zone: zone == '-' ? null : zone,
      longitude: longitude,
      male: sex == '-' ? null : sex == 'm',
      config: BaziConfig(
        timeMode: timeMode,
        ziHourRule: zi,
        yearBoundary: year,
        luckDivisor: divisor,
        luckAnchor: anchor,
        luckRounding: rounding,
      ),
      hidden: hidden,
      relations: relations,
    );
  }
}
