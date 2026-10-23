import 'dart:math' as math;

import 'civil_date.dart';
import 'sun.dart';

/// The four seasons the twelve mangsa fall into, three mangsa each.
enum MangsaSeason {
  /// The dry season.
  katiga('Katiga'),

  /// The turn towards the rains.
  labuh('Labuh'),

  /// The rains.
  rendheng('Rendheng'),

  /// The turn towards the dry season.
  mareng('Mareng');

  final String label;

  const MangsaSeason(this.label);
}

/// The older division of the year by how it is lived through, after
/// Daldjoeni (1984): clear skies, hardship, rain, and hope.
enum MangsaPhase {
  /// Clear skies: Sada and Kasa, 82 days.
  terang('Terang'),

  /// Hardship: Karo to Kalima, 99 days.
  semplah('Semplah'),

  /// Rain: Kanem and Kapitu, 86 days.
  udan('Udan'),

  /// Hope: Kawolu to Desta, 98 days, 99 in a long year.
  pangarepArep('Pangarep-arep');

  final String label;

  const MangsaPhase(this.label);
}

/// The twelve mangsa of the pranata mangsa, in the form the court of
/// Surakarta fixed in 1855.
///
/// [candra] is the image the mangsa is known by, in Javanese as the
/// primbon gives it. [alias] is its second name. [pecak] is the length
/// of a standing person's shadow at noon when the mangsa opens, in the
/// person's own feet, between Merapi and Lawu; [shadowSouth] says which
/// way it falls, and is null when the sun is overhead and there is none.
enum Mangsa {
  kasa(
    'Kasa',
    'Kartika',
    41,
    MangsaSeason.katiga,
    MangsaPhase.terang,
    'Sotya murca saking embanan',
    4,
    true,
  ),
  karo(
    'Karo',
    'Pusa',
    23,
    MangsaSeason.katiga,
    MangsaPhase.semplah,
    'Bantala rengka',
    3,
    true,
  ),
  katelu(
    'Katelu',
    'Manggasri',
    24,
    MangsaSeason.katiga,
    MangsaPhase.semplah,
    'Suta manut ing bapa',
    2,
    true,
  ),
  kapat(
    'Kapat',
    'Sitra',
    25,
    MangsaSeason.labuh,
    MangsaPhase.semplah,
    'Waspa kumembeng jroning kalbu',
    1,
    true,
  ),
  kalima(
    'Kalima',
    'Manggala',
    27,
    MangsaSeason.labuh,
    MangsaPhase.semplah,
    'Pancuran mas sumawur ing jagad',
    0,
    null,
  ),
  kanem(
    'Kanem',
    'Naya',
    43,
    MangsaSeason.labuh,
    MangsaPhase.udan,
    'Rasa mulya kasucian',
    1,
    false,
  ),
  kapitu(
    'Kapitu',
    'Palguna',
    43,
    MangsaSeason.rendheng,
    MangsaPhase.udan,
    'Wisa kentir ing maruta',
    2,
    false,
  ),
  kawolu(
    'Kawolu',
    'Wisaka',
    26,
    MangsaSeason.rendheng,
    MangsaPhase.pangarepArep,
    'Anjrah jroning kayun',
    1,
    false,
  ),
  kasanga(
    'Kasanga',
    'Jita',
    25,
    MangsaSeason.rendheng,
    MangsaPhase.pangarepArep,
    'Wedharing wacana mulya',
    0,
    null,
  ),
  kasadasa(
    'Kasadasa',
    'Srawana',
    24,
    MangsaSeason.mareng,
    MangsaPhase.pangarepArep,
    'Gedhong mineb jroning kalbu',
    1,
    true,
  ),
  desta(
    'Desta',
    'Padrawana',
    23,
    MangsaSeason.mareng,
    MangsaPhase.pangarepArep,
    'Sotya sinarawedi',
    2,
    true,
  ),
  sada(
    'Sada',
    'Asuji',
    41,
    MangsaSeason.mareng,
    MangsaPhase.terang,
    'Tirta sah saking sasana',
    3,
    true,
  );

  final String label;
  final String alias;

  /// Days in a short year (taun wastu). Kawolu has one more in a long
  /// year (taun wuntu).
  final int days;
  final MangsaSeason season;
  final MangsaPhase phase;
  final String candra;
  final int pecak;
  final bool? shadowSouth;

  const Mangsa(
    this.label,
    this.alias,
    this.days,
    this.season,
    this.phase,
    this.candra,
    this.pecak,
    this.shadowSouth,
  );

  /// The mangsa's place in the year, from 1.
  int get number => index + 1;
}

/// A date in the pranata mangsa, the Javanese calendar of the seasons.
///
/// It is a solar calendar tied to the Gregorian one. The year opens with
/// Kasa on 22 June, at the northern solstice; the twelve mangsa have 41,
/// 23, 24, 25, 27, 43, 43, 26, 25, 24, 23 and 41 days; and in a Gregorian
/// leap year Kawolu, which ends with February, has 27. Year 1 opened on
/// 22 June 1855. Dates before that are refused, not guessed: the fixed
/// form does not exist before then.
///
/// Where the sources differ, see `docs/pranata-mangsa-notes.md`.
class PranataMangsa {
  /// The year, counted from the one that opened on 22 June 1855.
  final int year;
  final Mangsa mangsa;

  /// The day within the mangsa, from 1.
  final int day;

  /// How many days this mangsa has in this year.
  final int length;

  /// Whether the year has 366 days (taun wuntu) and not 365 (taun wastu).
  final bool isLong;

  const PranataMangsa._(
    this.year,
    this.mangsa,
    this.day,
    this.length,
    this.isLong,
  );

  static final CivilDate epoch = CivilDate(1855, 6, 22);

  static bool supports(CivilDate date) => date.compareTo(epoch) >= 0;

  /// The Gregorian year in which the given pranata mangsa year opens.
  static int _opens(int year) => year + 1854;

  static bool _leap(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  /// The first day of a mangsa in the given pranata mangsa year.
  static CivilDate startOf(int year, Mangsa mangsa) {
    var days = CivilDate(_opens(year), 6, 22).dayNumber;
    for (final earlier in Mangsa.values.take(mangsa.index)) {
      days += lengthOf(year, earlier);
    }
    return CivilDate.fromDayNumber(days);
  }

  /// How long a mangsa is in the given pranata mangsa year.
  static int lengthOf(int year, Mangsa mangsa) =>
      mangsa == Mangsa.kawolu && _leap(_opens(year) + 1)
      ? mangsa.days + 1
      : mangsa.days;

  factory PranataMangsa.of(CivilDate date) {
    if (!supports(date)) {
      throw RangeError('Pranata mangsa starts on 22 June 1855, got $date');
    }
    final opened = date.compareTo(CivilDate(date.year, 6, 22)) >= 0
        ? date.year
        : date.year - 1;
    final year = opened - 1854;
    var left = date.dayNumber - CivilDate(opened, 6, 22).dayNumber;
    for (final mangsa in Mangsa.values) {
      final length = lengthOf(year, mangsa);
      if (left < length) {
        return PranataMangsa._(
          year,
          mangsa,
          left + 1,
          length,
          _leap(opened + 1),
        );
      }
      left -= length;
    }
    throw StateError('unreachable: $date is in no mangsa');
  }

  /// The latitude the court's shadow lengths are right for: the country
  /// between Merapi and Lawu.
  static const courtLatitude = -7.5;

  /// The length of a gnomon's shadow at local noon on [date], as a share
  /// of the gnomon's height: positive when it falls to the south, negative
  /// to the north. This is the measurement the mangsa are cut by.
  static double noonShadow(CivilDate date, {double latitude = courtLatitude}) {
    const rad = math.pi / 180;
    // Noon in Central Java, 05:00 UTC, is near enough for a day's
    // declination.
    final noon = DateTime.utc(date.year, date.month, date.day, 5);
    final day = Sun.julianDayOf(noon);
    final longitude = Sun.apparentLongitudeAt(day) * rad;
    final t = (day - 2451545.0) / 36525;
    final obliquity = (23.439291 - 0.0130042 * t) * rad;
    final declination = math.asin(math.sin(obliquity) * math.sin(longitude));
    return math.tan(declination - latitude * rad);
  }

  @override
  String toString() => '$day ${mangsa.label} $year';

  @override
  bool operator ==(Object other) =>
      other is PranataMangsa &&
      other.year == year &&
      other.mangsa == mangsa &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, mangsa, day);
}
