import 'chinese_table.dart';
import 'civil_date.dart';

/// The twelve animals of the Chinese zodiac, as named in Indonesia.
enum Shio {
  tikus('Tikus'),
  kerbau('Kerbau'),
  macan('Macan'),
  kelinci('Kelinci'),
  naga('Naga'),
  ular('Ular'),
  kuda('Kuda'),
  kambing('Kambing'),
  monyet('Monyet'),
  ayam('Ayam'),
  anjing('Anjing'),
  babi('Babi');

  final String label;

  const Shio(this.label);
}

/// The five elements that pair with the [Shio] over a sixty-year cycle.
enum Unsur {
  kayu('Kayu'),
  api('Api'),
  tanah('Tanah'),
  logam('Logam'),
  air('Air');

  final String label;

  const Unsur(this.label);
}

/// A date in the Chinese lunisolar calendar as used in Indonesia (Imlek).
///
/// Days and months are the standard Chinese calendar, read from the Hong
/// Kong Observatory's published tables. The Indonesian conventions are the
/// Kongzili year count and the Hokkien month names.
///
/// Supported from Imlek 1901 (19 February 1901) to the eve of Imlek 2100.
class ChineseDate {
  /// The Gregorian year in which this Chinese year began.
  final int year;

  /// 1..12. A leap month carries the number of the month it follows.
  final int month;
  final bool isLeapMonth;
  final int day;

  const ChineseDate._(this.year, this.month, this.isLeapMonth, this.day);

  static const _monthLabels = [
    'Cia Gwee',
    'Ji Gwee',
    'Sa Gwee',
    'Si Gwee',
    'Go Gwee',
    'Lak Gwee',
    'Cit Gwee',
    'Pe Gwee',
    'Kau Gwee',
    'Cap Gwee',
    'Cap It Gwee',
    'Cap Ji Gwee',
  ];

  static final _lastYear = chineseTableFirstYear + chineseTable.length - 1;

  static int _entry(int year) => chineseTable[year - chineseTableFirstYear];

  static int _newYearDayNumber(int year) =>
      CivilDate(year, 1, 1).dayNumber + (_entry(year) >> 17);

  static int _leapMonth(int year) => (_entry(year) >> 13) & 0xF;

  static int _monthCount(int year) => _leapMonth(year) == 0 ? 12 : 13;

  static int _monthLength(int year, int index) =>
      (_entry(year) >> index) & 1 == 1 ? 30 : 29;

  static int _yearLength(int year) {
    var days = 0;
    for (var i = 0; i < _monthCount(year); i++) {
      days += _monthLength(year, i);
    }
    return days;
  }

  static final CivilDate firstSupported = CivilDate.fromDayNumber(
    _newYearDayNumber(chineseTableFirstYear),
  );
  static final CivilDate lastSupported = CivilDate.fromDayNumber(
    _newYearDayNumber(_lastYear) + _yearLength(_lastYear) - 1,
  );

  static bool supports(CivilDate date) =>
      date.compareTo(firstSupported) >= 0 && date.compareTo(lastSupported) <= 0;

  factory ChineseDate.of(CivilDate date) {
    if (!supports(date)) {
      throw ArgumentError.value(
        date,
        'date',
        'outside the table ($firstSupported to $lastSupported)',
      );
    }
    var year = date.year <= _lastYear ? date.year : _lastYear;
    if (date.dayNumber < _newYearDayNumber(year)) year--;

    var remaining = date.dayNumber - _newYearDayNumber(year);
    final leap = _leapMonth(year);
    for (var i = 0; i < _monthCount(year); i++) {
      final length = _monthLength(year, i);
      if (remaining < length) {
        final isLeap = leap != 0 && i == leap;
        final month = leap != 0 && i >= leap ? i : i + 1;
        return ChineseDate._(year, month, isLeap, remaining + 1);
      }
      remaining -= length;
    }
    throw StateError('unreachable: $date');
  }

  /// The year counted from the birth of Confucius, as on Indonesian
  /// calendars ("Tahun Baru Imlek 2577 Kongzili").
  int get kongziliYear => year + 551;

  Shio get shio => Shio.values[(year - 4) % 12];

  Unsur get unsur => Unsur.values[(year - 4) % 10 ~/ 2];

  /// The element of a day: that of its heavenly stem in the sixty-day
  /// cycle, which has run unbroken for well over two thousand years and
  /// owes nothing to months or years. The ten stems go in pairs through
  /// wood, fire, earth, metal and water, so the element holds for two days
  /// and then moves on.
  ///
  /// Counted from the Julian day number: 1 October 1949 was a jiazi day,
  /// the first of the sixty.
  static Unsur dayUnsur(CivilDate date) =>
      Unsur.values[(date.dayNumber + 49) % 10 ~/ 2];

  /// Whether a day is yang: the first day of each element's pair is, and
  /// the second is yin. With [dayUnsur] it names the day's heavenly stem.
  static bool dayIsYang(CivilDate date) => (date.dayNumber + 49).isEven;

  String get monthLabel =>
      '${isLeapMonth ? 'Lun ' : ''}${_monthLabels[month - 1]}';

  @override
  bool operator ==(Object other) =>
      other is ChineseDate &&
      other.year == year &&
      other.month == month &&
      other.isLeapMonth == isLeapMonth &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, isLeapMonth, day);

  @override
  String toString() => '$day $monthLabel $kongziliYear';
}
