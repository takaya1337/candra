import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';

import '../appearance.dart';

/// A planet as the maps place it: where it stands from the place, and
/// how it is seen from the Earth.
typedef PlanetAt = ({Body body, SkyPosition at, PlanetView view});

/// How the planets look wherever they are drawn, and whether the star
/// map shows them.
abstract final class PlanetLook {
  /// Whether the star map and Lintang Jawa draw the planets; kept on the
  /// phone.
  static final shown = ValueNotifier<bool>(true);
  static const shownKey = 'planets_shown';

  /// Each in roughly the colour the eye sees it.
  static Color colorOf(Body body) => Legible.of(switch (body) {
    Body.mercury => const Color(0xFFB8AFA6),
    Body.venus => const Color(0xFFF4E9C8),
    Body.mars => const Color(0xFFE0734F),
    Body.jupiter => const Color(0xFFE8D2A8),
    Body.saturn => const Color(0xFFD9C27F),
    Body.uranus => const Color(0xFF9FD8DA),
    Body.neptune => const Color(0xFF7C9CE8),
    Body.sun || Body.moon => const Color(0xFFFFFFFF),
  });

  /// The symbol astronomers and alchemists write it with.
  static String symbolOf(Body body) => switch (body) {
    Body.mercury => '☿',
    // Drawn from the bundled Noto Sans Symbols, not the system's emoji
    // (SmType.symbols).
    Body.venus => '♀',
    Body.mars => '♂',
    Body.jupiter => '♃',
    Body.saturn => '♄',
    Body.uranus => '⛢',
    Body.neptune => '♆',
    Body.sun => '☉',
    Body.moon => '☽',
  };

  /// Where each of the seven stands from the place at [instant].
  static List<PlanetAt> at(
    DateTime instant, {
    required double latitude,
    required double longitude,
  }) => [
    for (final body in Planets.all)
      (
        body: body,
        at: SkyNow.planet(
          body,
          instant,
          latitude: latitude,
          longitude: longitude,
        ),
        view: SkyNow.planetView(body, instant),
      ),
  ];
}
