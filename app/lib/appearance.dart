import 'package:flutter/widgets.dart';

/// Whether the app is dark or light.
///
/// Until it is chosen it follows the phone. Choosing the side the phone is
/// already on goes back to following it, so the one two-sided toggle does
/// all three things: dark, light, and as the phone.
class AppearanceController extends ChangeNotifier {
  /// Called with the side chosen, or null when the app goes back to
  /// following the phone, to persist it.
  final void Function(Brightness? chosen)? onChange;

  Brightness? _chosen;

  AppearanceController({Brightness? saved, this.onChange}) : _chosen = saved;

  /// The side chosen, or null while the app follows the phone.
  Brightness? get chosen => _chosen;

  /// Which side the app is on, the phone being on [phone].
  Brightness of(Brightness phone) => _chosen ?? phone;

  /// Chooses [side], the phone being on [phone].
  void choose(Brightness side, Brightness phone) {
    final chosen = side == phone ? null : side;
    if (chosen == _chosen) return;
    _chosen = chosen;
    notifyListeners();
    onChange?.call(chosen);
  }
}

/// Gives the subtree the [AppearanceController].
class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({
    super.key,
    required AppearanceController super.notifier,
    required super.child,
  });

  static AppearanceController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()!.notifier!;
}

/// Colours fixed by meaning rather than by the theme (the elements, the
/// seasons, the prayers, the sun and the moon) were chosen to stand out
/// on the dark backgrounds. On the light ones the paler of them would
/// vanish, so while the app is light each is read deeper: the same hue,
/// its lightness brought down to [_lightInk].
///
/// The app's shell sets [light] as it builds, before anything below it;
/// everything that reads these colours is built under it and is built
/// again when the side changes.
abstract final class Legible {
  static bool light = false;

  static const _lightInk = 0.42;

  static Color of(Color color) {
    if (!light) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness <= _lightInk) return color;
    return hsl.withLightness(_lightInk).toColor();
  }

  // The deeper reading of each table, worked out once.
  static final _deep = Expando<Map<Object?, Color>>();

  /// [colors] read as [of] reads each.
  static Map<K, Color> map<K>(Map<K, Color> colors) {
    if (!light) return colors;
    return (_deep[colors] ??= <K, Color>{
          for (final e in colors.entries) e.key: of(e.value),
        })
        as Map<K, Color>;
  }
}
