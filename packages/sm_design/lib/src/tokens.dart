import 'package:flutter/widgets.dart';

class SmColors {
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;
  final Color accent;

  const SmColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.accent,
  });

  static SmColors lerp(SmColors a, SmColors b, double t) => SmColors(
    background: Color.lerp(a.background, b.background, t)!,
    surface: Color.lerp(a.surface, b.surface, t)!,
    surfaceRaised: Color.lerp(a.surfaceRaised, b.surfaceRaised, t)!,
    outline: Color.lerp(a.outline, b.outline, t)!,
    textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
    textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
    textFaint: Color.lerp(a.textFaint, b.textFaint, t)!,
    accent: Color.lerp(a.accent, b.accent, t)!,
  );
}

class SmSpacing {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  const SmSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
  });
}

class SmRadii {
  final double sm;
  final double md;
  final double lg;

  const SmRadii({this.sm = 6, this.md = 12, this.lg = 20});
}

/// Text styles carry family, size and spacing only; colour comes from
/// [SmColors] at the point of use.
///
/// Everything is set in one same-width face, IBM Plex Mono, but for the
/// day view's figure and weekday ([figureFamily]). The planets' signs
/// come from a few glyphs of Noto Sans Symbols ([symbols]), so the
/// system's emoji never stand in for ♀ and ♂. Other characters it lacks,
/// such as Chinese, fall back to the system font.
class SmType {
  static const family = 'IBMPlexMono';

  /// The face of the day view's great figure and the weekday under it,
  /// and nothing else.
  static const figureFamily = 'JetBrainsMono';
  static const package = 'sm_design';

  /// The faces tried after Plex for the planets' signs.
  static const symbols = ['NotoSansSymbols', 'NotoSansSymbols2'];

  final TextStyle display;
  final TextStyle title;
  final TextStyle body;
  final TextStyle label;
  final TextStyle caption;

  const SmType({
    this.display = const TextStyle(
      fontFamily: family,
      fontFamilyFallback: symbols,
      package: package,
      fontSize: 28,
      height: 1.2,
    ),
    this.title = const TextStyle(
      fontFamily: family,
      fontFamilyFallback: symbols,
      package: package,
      fontSize: 20,
      height: 1.3,
    ),
    this.body = const TextStyle(
      fontFamily: family,
      fontFamilyFallback: symbols,
      package: package,
      fontSize: 14,
      height: 1.3,
    ),
    this.label = const TextStyle(
      fontFamily: family,
      fontFamilyFallback: symbols,
      package: package,
      fontSize: 12,
      height: 1.3,
    ),
    this.caption = const TextStyle(
      fontFamily: family,
      fontFamilyFallback: symbols,
      package: package,
      fontSize: 10,
      height: 1.2,
    ),
  });
}

class SmMotion {
  final Duration fast;
  final Duration medium;
  final Duration slow;
  final Curve curve;

  /// For one layout turning into another: every moving part shares this
  /// duration and curve so the change reads as a single motion.
  final Duration transition;
  final Curve transitionCurve;

  /// For the whole app changing calendar system: quick, no ceremony.
  final Duration shift;
  final Curve shiftCurve;

  const SmMotion({
    this.fast = const Duration(milliseconds: 120),
    this.medium = const Duration(milliseconds: 280),
    this.slow = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.transition = const Duration(milliseconds: 460),
    this.transitionCurve = Curves.easeInOutCubicEmphasized,
    this.shift = const Duration(milliseconds: 180),
    this.shiftCurve = Curves.easeOut,
  });
}

class SmThemeData {
  final SmColors colors;
  final SmSpacing spacing;
  final SmRadii radii;
  final SmType type;
  final SmMotion motion;

  const SmThemeData({
    required this.colors,
    this.spacing = const SmSpacing(),
    this.radii = const SmRadii(),
    this.type = const SmType(),
    this.motion = const SmMotion(),
  });

  SmThemeData withColors(SmColors colors) => SmThemeData(
    colors: colors,
    spacing: spacing,
    radii: radii,
    type: type,
    motion: motion,
  );

  /// Placeholder palette until the real one is chosen.
  static const dusk = SmThemeData(
    colors: SmColors(
      background: Color(0xFF1B1612),
      surface: Color(0xFF241D17),
      surfaceRaised: Color(0xFF33291F),
      outline: Color(0xFF4A3D2E),
      textPrimary: Color(0xFFE8DCC4),
      textSecondary: Color(0xFF9C8F78),
      textFaint: Color(0xFF5C5245),
      accent: Color(0xFFC8963E),
    ),
  );
}
