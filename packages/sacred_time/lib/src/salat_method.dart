import 'indonesia_grid.g.dart';

import 'dart:convert';
import 'dart:typed_data';

/// How a place's prayer times are reckoned: Indonesia's ministry, or one
/// of the conventions used elsewhere, each as the body that keeps it
/// publishes it. The angles are the sun's centre below the horizon at
/// dawn (Subuh) and at nightfall (Isya); where Isya is a fixed time after
/// Magrib, [ishaInterval] minutes. [adjustments] are the minutes each
/// body adds to a time. The values are those the adhan library (Batoul
/// Apps, MIT) gives for each; sources in
/// `docs/provenance/sky-and-salat/notes.md`.
enum SalatMethod {
  /// Kementerian Agama, Indonesia: 20° and 18°, with its margins
  /// (`SalatTimes`).
  kemenag(fajrAngle: 20, ishaAngle: 18),

  /// Muslim World League: 18° and 17°.
  muslimWorldLeague(fajrAngle: 18, ishaAngle: 17, adjustments: {_zuhur: 1}),

  /// The Moonsighting Committee (Khalid Shaukat): 18° and 18°, made
  /// earlier and later by the season far from the equator, the seventh
  /// of the night from 55°.
  moonsightingCommittee(
    fajrAngle: 18,
    ishaAngle: 18,
    adjustments: {_zuhur: 5, _magrib: 3},
  ),

  /// Islamic Society of North America: 15° and 15°.
  northAmerica(fajrAngle: 15, ishaAngle: 15, adjustments: {_zuhur: 1}),

  /// Egyptian General Authority of Survey: 19.5° and 17.5°.
  egyptian(fajrAngle: 19.5, ishaAngle: 17.5, adjustments: {_zuhur: 1}),

  /// University of Islamic Sciences, Karachi: 18° and 18°.
  karachi(fajrAngle: 18, ishaAngle: 18, adjustments: {_zuhur: 1}),

  /// Umm al-Qura University, Makkah: 18.5°, and Isya 90 minutes after
  /// Magrib (120 in Ramadan).
  ummAlQura(fajrAngle: 18.5, ishaInterval: 90),

  /// Dubai: 18.2° and 18.2°.
  dubai(
    fajrAngle: 18.2,
    ishaAngle: 18.2,
    adjustments: {_terbit: -3, _zuhur: 3, _asar: 3, _magrib: 3},
  ),

  /// Kuwait: 18° and 17.5°.
  kuwait(fajrAngle: 18, ishaAngle: 17.5),

  /// Qatar: 18°, and Isya 90 minutes after Magrib.
  qatar(fajrAngle: 18, ishaInterval: 90),

  /// Singapore (MUIS), as Malaysia's JAKIM: 20° and 18°, rounded up.
  singapore(
    fajrAngle: 20,
    ishaAngle: 18,
    adjustments: {_zuhur: 1},
    roundUp: true,
  ),

  /// Diyanet, Turkey, as approximated: 18° and 17° with its own margins.
  turkey(
    fajrAngle: 18,
    ishaAngle: 17,
    adjustments: {_terbit: -7, _zuhur: 5, _asar: 4, _magrib: 7},
  ),

  /// Institute of Geophysics, University of Tehran: 17.7° and 14°, and
  /// Magrib with the sun 4.5° down.
  tehran(fajrAngle: 17.7, ishaAngle: 14, maghribAngle: 4.5);

  final double fajrAngle;
  final double ishaAngle;
  final int ishaInterval;
  final double? maghribAngle;
  final Map<String, int> adjustments;
  final bool roundUp;

  const SalatMethod({
    required this.fajrAngle,
    this.ishaAngle = 0,
    this.ishaInterval = 0,
    this.maghribAngle,
    this.adjustments = const {},
    this.roundUp = false,
  });

  /// The minutes this body adds to [time] (`subuh`, `terbit`, `zuhur`,
  /// `asar`, `magrib`, `isya`).
  int adjustment(String time) => adjustments[time] ?? 0;

  /// The conventions offered where Indonesia's is not the place's own,
  /// the likeliest for [latitude], [longitude] first: a suggestion by
  /// region, never a rule.
  static List<SalatMethod> suggestedFor(double latitude, double longitude) {
    // In order, each once.
    return <SalatMethod>{
      ..._region(latitude, longitude),
      muslimWorldLeague,
      for (final m in values)
        if (m != kemenag) m,
    }.toList();
  }

  // Coarse regions, for the order of the list only.
  static List<SalatMethod> _region(double lat, double lon) {
    bool box(double s, double n, double w, double e) =>
        lat >= s && lat <= n && lon >= w && lon <= e;
    if (box(35.8, 42.2, 25.6, 44.9)) return [turkey, muslimWorldLeague];
    if (box(25, 40, 44, 63.5)) return [tehran];
    if (box(22, 26.5, 51, 56.5)) return [dubai];
    if (box(24.4, 26.3, 50.7, 51.7)) return [qatar];
    if (box(28.5, 30.2, 46.5, 48.5)) return [kuwait];
    if (box(12, 32.5, 34.5, 60)) return [ummAlQura];
    if (box(-5, 7.5, 99, 120)) return [singapore];
    if (box(5, 38, 60.5, 98)) return [karachi];
    if (box(-35, 38, -20, 52)) return [egyptian];
    if (box(14, 72, -170, -50)) return [northAmerica, moonsightingCommittee];
    if (box(34, 72, -25, 45)) return [muslimWorldLeague, moonsightingCommittee];
    return [muslimWorldLeague];
  }
}

const _terbit = 'terbit';
const _zuhur = 'zuhur';
const _asar = 'asar';
const _magrib = 'magrib';

/// The length of shadow Asar is reckoned by.
enum Madhab {
  /// Shafi'i, Maliki, Hanbali: a shadow its thing's length beyond noon's.
  standard(1),

  /// Hanafi: twice its length.
  hanafi(2);

  final double shadow;

  const Madhab(this.shadow);
}

/// Where the sun never sinks far enough for dawn or nightfall by the
/// angles, or sinks so little that they fall absurdly late or early: the
/// latest Isya and the earliest Subuh are held to a part of the night,
/// sunset to sunrise.
enum HighLatitudeRule {
  /// No later than half the night after sunset, no earlier than half
  /// before sunrise.
  middleOfTheNight,

  /// A seventh of the night.
  seventhOfTheNight,

  /// The angle over 60 of the night: 18° makes 18/60.
  twilightAngle;

  /// A seventh above 48°, the middle below.
  static HighLatitudeRule recommended(double latitude) =>
      latitude.abs() > 48 ? seventhOfTheNight : middleOfTheNight;
}

/// Whether a place, to a tenth of a degree, is Indonesia's: on its land,
/// or at sea nearer its land than any other country's. From Natural Earth
/// (public domain); it chooses the prayer reckoning only.
abstract final class Indonesia {
  static Uint8List? _bits;

  static bool has(double latitude, double longitude) {
    final i = ((latitude - indonesiaSouth) * 10).round();
    final j = ((longitude - indonesiaWest) * 10).round();
    if (i < 0 || i >= indonesiaRows || j < 0 || j >= indonesiaColumns) {
      return false;
    }
    final bits = _bits ??= base64.decode(indonesiaGrid);
    final k = i * indonesiaColumns + j;
    return (bits[k >> 3] >> (k & 7)) & 1 == 1;
  }
}
