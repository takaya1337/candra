import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'iris_label.dart';

/// The colour of things that destroy: the delete-card button and its
/// confirmation.
const dangerColor = Color(0xFFFF6B47);

/// A pill button for the bottom bar. Its width follows its label smoothly.
///
/// With [onHold], holding it down fills it from the centre and then fires.
class BarButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onHold;
  final bool filled;
  final bool primary;

  /// Draws the frame and label in this colour in place of the accent:
  /// for a primary button that destroys something.
  final Color? tint;

  /// Shows a dot beside the label.
  final bool marked;

  /// Less room either side of the label, for a bar with many buttons.
  final bool compact;

  /// Less room above and below the label too: a tab in a row of them.
  final bool small;

  const BarButton({
    super.key,
    required this.label,
    required this.onTap,
    this.onHold,
    this.filled = false,
    this.primary = false,
    this.tint,
    this.marked = false,
    this.compact = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    if (onHold == null) {
      return SmPressable(onTap: onTap, child: _pill(context, 0));
    }
    return SmHoldPressable(onTap: onTap, onHold: onHold!, builder: _pill);
  }

  Widget _pill(BuildContext context, double holdProgress) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final radius = BorderRadius.circular(theme.radii.lg);

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          color: primary ? (tint ?? colors.accent) : colors.outline,
        ),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        // Background, then the hold's fill, then the label on top.
        child: ColoredBox(
          color: filled || primary
              ? colors.surfaceRaised
              : colors.surfaceRaised.withValues(alpha: 0),
          child: CustomPaint(
            painter: SmRadialFillPainter(
              progress: holdProgress,
              color: colors.accent.withValues(alpha: 0.45),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact
                    ? spacing.md
                    : primary
                    ? spacing.xl
                    : spacing.lg,
                vertical: small ? spacing.xs + 2 : spacing.sm + spacing.xs,
              ),
              // Resizes as the label's iris opens on its new content.
              child: AnimatedSize(
                duration: IrisLabel.openDuration,
                curve: IrisLabel.openCurve,
                child: IrisLabel(
                  text: label,
                  marked: marked,
                  markColor: colors.accent,
                  style: theme.type.label.copyWith(
                    color: primary
                        ? (tint ?? colors.accent)
                        : colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
