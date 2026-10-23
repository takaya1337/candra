import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'calendar_system.dart';

/// The colour schemes a calendar system can be shown in, each for the dark
/// side and the light. The first five are the systems' own; any system
/// may take any scheme, and two may share one.
enum ColourScheme {
  amber(
    SmColors(
      background: Color(0xFF1B1612),
      surface: Color(0xFF241D17),
      surfaceRaised: Color(0xFF33291F),
      outline: Color(0xFF4A3D2E),
      textPrimary: Color(0xFFE8DCC4),
      textSecondary: Color(0xFF9C8F78),
      textFaint: Color(0xFF5C5245),
      accent: Color(0xFFC8963E),
    ),
    SmColors(
      background: Color(0xFFF7F1E7),
      surface: Color(0xFFEFE7DA),
      surfaceRaised: Color(0xFFE4D9C7),
      outline: Color(0xFFD1C3AB),
      textPrimary: Color(0xFF2B2219),
      textSecondary: Color(0xFF6E604C),
      textFaint: Color(0xFFA69780),
      accent: Color(0xFFA06E22),
    ),
  ),
  moss(
    SmColors(
      background: Color(0xFF141A14),
      surface: Color(0xFF1B231B),
      surfaceRaised: Color(0xFF273226),
      outline: Color(0xFF3A4A38),
      textPrimary: Color(0xFFE4E3CC),
      textSecondary: Color(0xFF939A7E),
      textFaint: Color(0xFF545B48),
      accent: Color(0xFF9DB36A),
    ),
    SmColors(
      background: Color(0xFFF2F5EC),
      surface: Color(0xFFE8EDE0),
      surfaceRaised: Color(0xFFDAE2CF),
      outline: Color(0xFFC1CBB3),
      textPrimary: Color(0xFF1F261C),
      textSecondary: Color(0xFF5B654E),
      textFaint: Color(0xFF98A189),
      accent: Color(0xFF627E37),
    ),
  ),
  vermilion(
    SmColors(
      background: Color(0xFF1C1313),
      surface: Color(0xFF261919),
      surfaceRaised: Color(0xFF362222),
      outline: Color(0xFF4F3230),
      textPrimary: Color(0xFFEFDCD0),
      textSecondary: Color(0xFFA58A7E),
      textFaint: Color(0xFF61504A),
      accent: Color(0xFFD4573F),
    ),
    SmColors(
      background: Color(0xFFF9F0EC),
      surface: Color(0xFFF2E5E0),
      surfaceRaised: Color(0xFFE8D5CE),
      outline: Color(0xFFD6BCB3),
      textPrimary: Color(0xFF2E1D1A),
      textSecondary: Color(0xFF795C54),
      textFaint: Color(0xFFAF9890),
      accent: Color(0xFFB6402A),
    ),
  ),
  teal(
    SmColors(
      background: Color(0xFF111A1B),
      surface: Color(0xFF172325),
      surfaceRaised: Color(0xFF213235),
      outline: Color(0xFF324A4E),
      textPrimary: Color(0xFFD9E6E3),
      textSecondary: Color(0xFF86A09D),
      textFaint: Color(0xFF4A5F5E),
      accent: Color(0xFF5FB8AA),
    ),
    SmColors(
      background: Color(0xFFEDF5F4),
      surface: Color(0xFFE2EDEB),
      surfaceRaised: Color(0xFFD2E2E0),
      outline: Color(0xFFB5CCC9),
      textPrimary: Color(0xFF172523),
      textSecondary: Color(0xFF4D6764),
      textFaint: Color(0xFF8CA4A1),
      accent: Color(0xFF2A8577),
    ),
  ),
  // Candra's own: the sigil's night and its moonlight (#0B1B2E and
  // #F4F1E8, as the icon, the launch screen and the store's art have
  // them), Gregorian's since 23 October 2026.
  night(
    SmColors(
      background: Color(0xFF0B1B2E),
      surface: Color(0xFF11253D),
      surfaceRaised: Color(0xFF183050),
      outline: Color(0xFF2A4467),
      textPrimary: Color(0xFFF4F1E8),
      textSecondary: Color(0xFF97A3B4),
      textFaint: Color(0xFF52627A),
      accent: Color(0xFFA9C1E6),
    ),
    SmColors(
      background: Color(0xFFF4F1E8),
      surface: Color(0xFFEBE7DA),
      surfaceRaised: Color(0xFFDFD9C8),
      outline: Color(0xFFC9C3AF),
      textPrimary: Color(0xFF0B1B2E),
      textSecondary: Color(0xFF4A586C),
      textFaint: Color(0xFF969A9E),
      accent: Color(0xFF2B5089),
    ),
  ),
  slate(
    SmColors(
      background: Color(0xFF14171B),
      surface: Color(0xFF1B1F25),
      surfaceRaised: Color(0xFF272D35),
      outline: Color(0xFF3A424D),
      textPrimary: Color(0xFFDDE2E8),
      textSecondary: Color(0xFF8A939E),
      textFaint: Color(0xFF4F5660),
      accent: Color(0xFF8FA8C4),
    ),
    SmColors(
      background: Color(0xFFEFF2F6),
      surface: Color(0xFFE5E9EF),
      surfaceRaised: Color(0xFFD7DDE6),
      outline: Color(0xFFBEC6D1),
      textPrimary: Color(0xFF1B2129),
      textSecondary: Color(0xFF586372),
      textFaint: Color(0xFF96A0AD),
      accent: Color(0xFF4C6A8E),
    ),
  ),
  indigo(
    SmColors(
      background: Color(0xFF151628),
      surface: Color(0xFF1C1E33),
      surfaceRaised: Color(0xFF282A45),
      outline: Color(0xFF3B3E60),
      textPrimary: Color(0xFFDEDFF0),
      textSecondary: Color(0xFF8E91AD),
      textFaint: Color(0xFF4F5270),
      accent: Color(0xFF8C8FE0),
    ),
    SmColors(
      background: Color(0xFFF1F1F8),
      surface: Color(0xFFE6E7F2),
      surfaceRaised: Color(0xFFD8D9EA),
      outline: Color(0xFFBFC1DA),
      textPrimary: Color(0xFF1C1D2E),
      textSecondary: Color(0xFF595B7A),
      textFaint: Color(0xFF9799B5),
      accent: Color(0xFF4C4FA8),
    ),
  ),
  plum(
    SmColors(
      background: Color(0xFF1A1420),
      surface: Color(0xFF231B2A),
      surfaceRaised: Color(0xFF32263C),
      outline: Color(0xFF4A3858),
      textPrimary: Color(0xFFE9DDEC),
      textSecondary: Color(0xFFA08FA6),
      textFaint: Color(0xFF5F5265),
      accent: Color(0xFFB97FC4),
    ),
    SmColors(
      background: Color(0xFFF6F0F7),
      surface: Color(0xFFEEE4EF),
      surfaceRaised: Color(0xFFE2D4E5),
      outline: Color(0xFFCDB8D1),
      textPrimary: Color(0xFF291D2C),
      textSecondary: Color(0xFF6C5772),
      textFaint: Color(0xFFA592AA),
      accent: Color(0xFF85479A),
    ),
  ),
  rose(
    SmColors(
      background: Color(0xFF1E1417),
      surface: Color(0xFF291B1F),
      surfaceRaised: Color(0xFF3A262C),
      outline: Color(0xFF553840),
      textPrimary: Color(0xFFF0DDE2),
      textSecondary: Color(0xFFA98A92),
      textFaint: Color(0xFF664F55),
      accent: Color(0xFFD97A95),
    ),
    SmColors(
      background: Color(0xFFFAF0F2),
      surface: Color(0xFFF3E4E8),
      surfaceRaised: Color(0xFFE9D3DA),
      outline: Color(0xFFD7B8C1),
      textPrimary: Color(0xFF2E1D21),
      textSecondary: Color(0xFF7B5A63),
      textFaint: Color(0xFFB3959D),
      accent: Color(0xFFA9425F),
    ),
  ),
  ocean(
    SmColors(
      background: Color(0xFF101722),
      surface: Color(0xFF16202E),
      surfaceRaised: Color(0xFF1F2D40),
      outline: Color(0xFF2E425C),
      textPrimary: Color(0xFFD8E3F0),
      textSecondary: Color(0xFF8296AE),
      textFaint: Color(0xFF46566B),
      accent: Color(0xFF4F9BE0),
    ),
    SmColors(
      background: Color(0xFFEDF3FA),
      surface: Color(0xFFE1EAF5),
      surfaceRaised: Color(0xFFD0DDEE),
      outline: Color(0xFFB2C5DE),
      textPrimary: Color(0xFF152030),
      textSecondary: Color(0xFF4A5F7A),
      textFaint: Color(0xFF8A9DB6),
      accent: Color(0xFF1F6BB0),
    ),
  ),
  stone(
    SmColors(
      background: Color(0xFF161616),
      surface: Color(0xFF1E1E1E),
      surfaceRaised: Color(0xFF2A2A2A),
      outline: Color(0xFF404040),
      textPrimary: Color(0xFFE4E4E4),
      textSecondary: Color(0xFF959595),
      textFaint: Color(0xFF555555),
      accent: Color(0xFFB0A898),
    ),
    SmColors(
      background: Color(0xFFF3F3F2),
      surface: Color(0xFFEAEAE8),
      surfaceRaised: Color(0xFFDDDDDA),
      outline: Color(0xFFC5C5C1),
      textPrimary: Color(0xFF1E1E1D),
      textSecondary: Color(0xFF5E5E5B),
      textFaint: Color(0xFF9C9C98),
      accent: Color(0xFF6E6A60),
    ),
  );

  final SmColors dark;
  final SmColors light;

  const ColourScheme(this.dark, this.light);

  SmColors on(Brightness side) => side == Brightness.light ? light : dark;
}

/// Which scheme each calendar system is shown in: its own until changed
/// in the menu's Colours, kept on the phone.
abstract final class ColourChoice {
  static const defaults = {
    CalendarSystem.weton: ColourScheme.amber,
    CalendarSystem.javanese: ColourScheme.moss,
    CalendarSystem.chinese: ColourScheme.vermilion,
    CalendarSystem.hijri: ColourScheme.teal,
    CalendarSystem.gregorian: ColourScheme.night,
  };

  static final chosen = ValueNotifier<Map<CalendarSystem, ColourScheme>>(
    defaults,
  );

  static ColourScheme of(CalendarSystem system) =>
      chosen.value[system] ?? defaults[system]!;

  static void choose(CalendarSystem system, ColourScheme scheme) =>
      chosen.value = {...chosen.value, system: scheme};

  static void restore() => chosen.value = defaults;

  static bool get isDefault =>
      CalendarSystem.values.every((s) => of(s) == defaults[s]);

  /// "weton=amber,javanese=moss,…", for the preferences.
  static String encode() =>
      [for (final s in CalendarSystem.values) '${s.name}=${of(s).name}']
          .join(',');

  static void decode(String? text) {
    final map = {...defaults};
    for (final part in (text ?? '').split(',')) {
      final [system, scheme] = [...part.split('='), '', ''].take(2).toList();
      final s = CalendarSystem.values
          .where((v) => v.name == system)
          .firstOrNull;
      final c = ColourScheme.values.where((v) => v.name == scheme).firstOrNull;
      if (s != null && c != null) map[s] = c;
    }
    chosen.value = map;
  }
}
