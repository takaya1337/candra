import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'appearance.dart';
import 'calendar_system.dart';
import 'colour_schemes.dart';

/// Each calendrical system tints the whole app, in the scheme chosen for
/// it (its own unless changed, [ColourChoice]). The tints sit close
/// together in lightness so a shift reads as a change of mood, not a
/// flash.
extension SystemPalette on CalendarSystem {
  SmColors get colors => ColourChoice.of(this).dark;

  /// The same tint for the light side: the same hues, the backgrounds
  /// pale and warm or cool as the dark ones are, the text dark, and the
  /// accent deepened so it still reads on paper.
  SmColors get lightColors => ColourChoice.of(this).light;

  /// The tint for [side].
  SmColors on(Brightness side) =>
      side == Brightness.light ? lightColors : colors;

  /// The tint on the side the app is on now (see [Legible.light]): for
  /// what shows a system other than the active one, in its own colours.
  SmColors get shown => Legible.light ? lightColors : colors;
}
