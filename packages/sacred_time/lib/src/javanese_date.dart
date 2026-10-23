import 'civil_date.dart';

/// The twelve months of the Javanese lunar year.
enum JavaneseMonth {
  sura('Sura'),
  sapar('Sapar'),
  mulud('Mulud'),
  bakdamulud('Bakdamulud'),
  jumadilawal('Jumadilawal'),
  jumadilakir('Jumadilakir'),
  rejeb('Rejeb'),
  ruwah('Ruwah'),
  pasa('Pasa'),
  sawal('Sawal'),
  dulkangidah('Dulkangidah'),
  besar('Besar');

  final String label;

  const JavaneseMonth(this.label);
}

/// The eight year names of a windu. Ehe, Dal and Jimakir are long years
/// (taun wuntu, 355 days); the rest are short (taun wastu, 354 days).
enum Taun {
  alip('Alip', 354),
  ehe('Ehe', 355),
  jimawal('Jimawal', 354),
  je('Je', 354),
  dal('Dal', 355),
  be('Be', 354),
  wawu('Wawu', 354),
  jimakir('Jimakir', 355);

  final String label;
  final int days;

  const Taun(this.label, this.days);

  bool get isLong => days == 355;
}

/// A date in Sultan Agung's Javanese calendar (Anno Javanico), computed by
/// the tabular rules of kurup Asapon (Alip Selasa Pon).
///
/// Only kurup Asapon is supported: 1 Sura 1867 (24 March 1936) through
/// 29 Besar 1986 (25 August 2052). Earlier kurup have irregular lengths and
/// differ between Surakarta and Yogyakarta; the kurup after Asapon has not
/// been defined by the courts.
///
/// Here the day turns at civil midnight, as every [CivilDate] does; by
/// tradition the Javanese day begins at sunset, the evening before.
class JavaneseDate {
  /// Year in Anno Javanico.
  final int year;
  final JavaneseMonth month;
  final int day;

  const JavaneseDate._(this.year, this.month, this.day);

  static const _firstYear = 1867;
  static const _daysPerWindu = 2835;

  // 15 windu, less the one day a kurup drops from its final Besar.
  static const _daysInKurup = 15 * _daysPerWindu - 1;

  static final _epoch = CivilDate(1936, 3, 24).dayNumber;

  static final CivilDate firstSupported = CivilDate.fromDayNumber(_epoch);
  static final CivilDate lastSupported = CivilDate.fromDayNumber(
    _epoch + _daysInKurup - 1,
  );

  static bool supports(CivilDate date) {
    final offset = date.dayNumber - _epoch;
    return offset >= 0 && offset < _daysInKurup;
  }

  factory JavaneseDate.of(CivilDate date) {
    if (!supports(date)) {
      throw ArgumentError.value(
        date,
        'date',
        'outside kurup Asapon ($firstSupported to $lastSupported)',
      );
    }
    var remaining = date.dayNumber - _epoch;
    var year = _firstYear + 8 * (remaining ~/ _daysPerWindu);
    remaining %= _daysPerWindu;

    for (final taun in Taun.values) {
      if (remaining < taun.days) break;
      remaining -= taun.days;
      year++;
    }

    final taun = taunOf(year);
    for (final month in JavaneseMonth.values) {
      final length = daysInMonth(taun, month);
      if (remaining < length) return JavaneseDate._(year, month, remaining + 1);
      remaining -= length;
    }
    throw StateError('unreachable: $date');
  }

  static Taun taunOf(int year) => Taun.values[(year - _firstYear) % 8];

  /// Months alternate 30 and 29 days; Besar has 30 in a long year.
  static int daysInMonth(Taun taun, JavaneseMonth month) {
    if (month == JavaneseMonth.besar) return taun.isLong ? 30 : 29;
    return month.index.isEven ? 30 : 29;
  }

  Taun get taun => taunOf(year);

  @override
  bool operator ==(Object other) =>
      other is JavaneseDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$day ${month.label} $year ${taun.label}';
}
