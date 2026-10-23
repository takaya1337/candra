import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Where an entry was written: its geotag. One per entry at most.
///
/// The coordinates are rounded to three decimal places before they are
/// kept, which is about a hundred metres: enough to tell one place from
/// the next, and never the exact spot. The name is whatever the writer
/// calls the place, and may be empty.
class GeoTag {
  /// Decimal places kept. One thousandth of a degree of latitude is 111
  /// metres.
  static const decimals = 3;

  /// How close, in metres, a named place has to be to be offered as the
  /// name of this one.
  static const nearby = 300.0;

  final double latitude;
  final double longitude;
  final String name;

  const GeoTag._(this.latitude, this.longitude, this.name);

  /// The tag for a position, rounded. Null if it is not on the globe.
  static GeoTag? rounded(
    double latitude,
    double longitude, {
    String name = '',
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return GeoTag._(_round(latitude), _round(longitude), _oneLine(name));
  }

  static double _round(double degrees) {
    final scale = math.pow(10, decimals);
    // Not "-0.0".
    return (degrees * scale).round() / scale + 0.0;
  }

  static String _oneLine(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  GeoTag named(String name) => GeoTag._(latitude, longitude, _oneLine(name));

  /// "-7.801, 110.365": as any maps app takes it.
  String get coordinates =>
      '${latitude.toStringAsFixed(decimals)}, '
      '${longitude.toStringAsFixed(decimals)}';

  /// The name, or the coordinates of a place with none.
  String get label => name.isEmpty ? coordinates : name;

  /// Metres to [other], near enough over the short distances asked of it.
  double distanceTo(GeoTag other) {
    const metresPerDegree = 111320.0;
    final north = (other.latitude - latitude) * metresPerDegree;
    final east =
        (other.longitude - longitude) *
        metresPerDegree *
        math.cos(latitude * math.pi / 180);
    return math.sqrt(north * north + east * east);
  }

  @override
  bool operator ==(Object other) =>
      other is GeoTag &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.name == name;

  @override
  int get hashCode => Object.hash(latitude, longitude, name);

  @override
  String toString() => name.isEmpty ? coordinates : '$name ($coordinates)';
}

/// Why the phone could not say where it is.
enum LocateProblem {
  /// The app is not allowed to use location.
  denied,

  /// Location is switched off on the phone.
  off,

  /// Nothing came back in time.
  timeout,

  /// Nothing came back in time, and the phone has only its satellites to
  /// go by (Wi-Fi and network positioning are off): it needs open sky.
  sky,

  /// The user stopped it.
  cancelled,

  /// The phone has no way to tell.
  unavailable,
}

class LocateFailed implements Exception {
  final LocateProblem problem;

  const LocateFailed(this.problem);
}

/// A position as the phone gave it, before rounding.
typedef Fix = ({double latitude, double longitude, double accuracy});

/// Asks the phone where it is, and hands a place to its maps app.
///
/// Only ever asked when the geotag button is pressed: never in the
/// background, and never unless the user asks.
abstract class Locator {
  const Locator();

  /// The one in use; replaced in tests.
  static Locator current = const PhoneLocator();

  /// Where the phone is now. Asks for permission the first time. Throws
  /// [LocateFailed].
  Future<Fix> find();

  /// Whether the phone already lets the app read where it is. Asks
  /// nothing: no prompt is ever raised by this.
  Future<bool> allowed() async => false;

  /// Stops a [find] that is still looking; it then fails as
  /// [LocateProblem.cancelled].
  Future<void> cancel();

  /// Opens [place] in whatever maps app the phone has. False if it has
  /// none.
  Future<bool> open(GeoTag place);
}

class PhoneLocator extends Locator {
  const PhoneLocator();

  static const _channel = MethodChannel('candra/location');

  @override
  Future<Fix> find() async {
    try {
      final fix = await _channel.invokeMapMethod<String, double>('current');
      return (
        latitude: fix!['latitude']!,
        longitude: fix['longitude']!,
        accuracy: fix['accuracy'] ?? 0,
      );
    } on PlatformException catch (error) {
      throw LocateFailed(
        LocateProblem.values.asNameMap()[error.code] ??
            LocateProblem.unavailable,
      );
    } on MissingPluginException {
      throw const LocateFailed(LocateProblem.unavailable);
    }
  }

  @override
  Future<bool> allowed() async {
    try {
      return await _channel.invokeMethod<bool>('allowed') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException {
      // Nothing was looking.
    } on MissingPluginException {
      // No phone to ask.
    }
  }

  @override
  Future<bool> open(GeoTag place) async {
    try {
      return await _channel.invokeMethod<bool>('open', {
            'latitude': place.latitude,
            'longitude': place.longitude,
            'label': place.name,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
