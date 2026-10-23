import 'package:flutter/foundation.dart';

import 'journal/geo.dart';

/// The place the sun's and moon's rise and set times are worked out for.
///
/// Set, if at all, from the phone's own position when the user asks in
/// detailed mode, and rounded to one decimal place first: about ten
/// kilometres, which moves a sunrise by well under a minute and says
/// nothing of where anyone lives. Null until it is set; the times that
/// need it are then left out.
abstract final class SkyPlace {
  /// Sets the place to where the phone is now, if the phone already lets
  /// the app read that, and otherwise leaves it as it is: never asks
  /// (owner, 21 October 2026: today, and opening a utility, recentre the
  /// place too, if it was given).
  static Future<void> recentre() async {
    final locator = Locator.current;
    if (!await locator.allowed()) return;
    try {
      final fix = await locator.find();
      current.value = rounded(fix.latitude, fix.longitude);
    } on LocateFailed {
      // Not found just now: the place stays.
    }
  }

  static final current = ValueNotifier<({double latitude, double longitude})?>(
    null,
  );

  /// Where it is kept in the phone's preferences.
  static const latitudeKey = 'sky_latitude';
  static const longitudeKey = 'sky_longitude';

  /// The place, rounded as it is kept.
  static ({double latitude, double longitude}) rounded(
    double latitude,
    double longitude,
  ) => (
    latitude: (latitude * 10).round() / 10 + 0.0,
    longitude: (longitude * 10).round() / 10 + 0.0,
  );

  /// "-7.8, 110.4".
  static String label(({double latitude, double longitude}) place) =>
      '${place.latitude.toStringAsFixed(1)}, '
      '${place.longitude.toStringAsFixed(1)}';
}
