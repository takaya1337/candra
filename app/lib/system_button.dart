import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'calendar_system.dart';
import 'system_glyph.dart';

/// The button at the centre of the bar: the chosen calendar system, as
/// its glyph. A glyph, not the system's name, so the button is the same
/// size whatever the system and the language, and never moves.
///
/// A tap opens the system picker; a hold fills it from the centre and
/// then locks the system, or releases the lock. A dot marks a system
/// that is locked.
class SystemButton extends StatelessWidget {
  final CalendarSystem system;
  final VoidCallback onTap;
  final VoidCallback onHold;
  final bool marked;

  /// Lit from behind: the house is in the living room (see `House`).
  final bool here;

  const SystemButton({
    super.key,
    required this.system,
    required this.onTap,
    required this.onHold,
    this.marked = false,
    this.here = false,
  });

  /// The glyph's size: with its padding, as tall as any bar button.
  static const glyphSize = 24.0;

  @override
  Widget build(BuildContext context) =>
      SmHoldPressable(onTap: onTap, onHold: onHold, builder: _pill);

  Widget _pill(BuildContext context, double holdProgress) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final radius = BorderRadius.circular(theme.radii.lg);

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: here ? colors.accent : colors.outline),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        // While the house is in the living room, its inverse: the pill
        // solid in the accent, the glyph in the ground's colour on it
        // (owner, 21 October 2026). Elsewhere the glyph on nothing.
        child: AnimatedContainer(
          duration: theme.motion.medium,
          curve: theme.motion.curve,
          color: colors.accent.withValues(alpha: here ? 1 : 0),
          child: CustomPaint(
            painter: SmRadialFillPainter(
              progress: holdProgress,
              color: colors.accent.withValues(alpha: 0.45),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    // 56 wide in all, a little wider than the bar's other
                    // buttons, as wide as the tick that stands in for it.
                    horizontal: spacing.md,
                    // 16 is the line of a bar button's label.
                    vertical: spacing.sm + spacing.xs - (glyphSize - 16) / 2,
                  ),
                  // One glyph gives way to the next when the system
                  // changes.
                  child: AnimatedSwitcher(
                    duration: theme.motion.medium,
                    child: SystemGlyph(
                      key: ValueKey((system, here)),
                      system: system,
                      size: glyphSize,
                      color: here ? colors.background : colors.accent,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 8,
                  child: AnimatedOpacity(
                    opacity: marked ? 1 : 0,
                    duration: theme.motion.medium,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
