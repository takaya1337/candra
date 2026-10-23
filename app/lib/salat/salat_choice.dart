import 'package:flutter/foundation.dart';
import 'package:sacred_time/sacred_time.dart';

/// How prayer times are reckoned where Indonesia's ministry is not the
/// place's own: the convention chosen (none until one is), the madhab for
/// Asar, and the rule far north and south (the recommended one for the
/// latitude unless chosen). Kept on the phone; set in the prayer times'
/// Method panel.
abstract final class SalatChoice {
  static final method = ValueNotifier<SalatMethod?>(null);
  static final madhab = ValueNotifier<Madhab>(Madhab.standard);
  static final highLatitude = ValueNotifier<HighLatitudeRule?>(null);

  static final Listenable all = Listenable.merge([
    method,
    madhab,
    highLatitude,
  ]);

  /// The convention a place's times are reckoned by: the ministry's in
  /// Indonesia, always; elsewhere the one chosen, or null until then.
  static SalatMethod? methodAt(({double latitude, double longitude}) place) =>
      Indonesia.has(place.latitude, place.longitude)
      ? SalatMethod.kemenag
      : method.value;
}
